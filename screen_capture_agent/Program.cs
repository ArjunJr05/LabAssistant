using System;
using System.Drawing;
using System.Drawing.Imaging;
using System.IO;
using System.Net;
using System.Net.WebSockets;
using System.Text;
using System.Threading;
using System.Threading.Tasks;
using System.Windows.Forms;
using Newtonsoft.Json;

namespace ScreenCaptureAgent
{
    class Program
    {
        private const int TARGET_FPS = 10;
        private const int CAPTURE_WIDTH = 1280;
        private const int CAPTURE_HEIGHT = 720;
        private const int WEBSOCKET_PORT = 8765;
        private const long JPEG_QUALITY = 60L;

        private static HttpListener _httpListener;
        private static bool _isRunning = false;
        private static System.Threading.Timer _captureTimer;
        private static readonly object _captureLock = new object();

        static async Task Main(string[] args)
        {
            Console.Title = "Lab Assistant - Screen Capture Agent";
            Console.WriteLine("=== Lab Assistant Screen Capture Agent ===");
            Console.WriteLine("Press Ctrl+C to stop the agent");
            
            // Handle Ctrl+C gracefully
            Console.CancelKeyPress += (sender, e) =>
            {
                e.Cancel = true;
                Stop();
                Environment.Exit(0);
            };
            
            await StartAsync();
        }

        static async Task StartAsync()
        {
            try
            {
                Console.WriteLine("Starting Screen Capture Agent...");
                
                // Get local IP address
                string localIP = GetLocalIPAddress();
                Console.WriteLine($"Local IP: {localIP}");
                
                // Start HTTP listener for WebSocket connections
                _httpListener = new HttpListener();
                _httpListener.Prefixes.Add($"http://{localIP}:{WEBSOCKET_PORT}/");
                _httpListener.Prefixes.Add($"http://localhost:{WEBSOCKET_PORT}/");
                _httpListener.Start();
                
                _isRunning = true;
                Console.WriteLine($"Screen Capture Agent started on port {WEBSOCKET_PORT}");
                Console.WriteLine("Waiting for admin connections...");
                
                // Start accepting WebSocket connections
                _ = Task.Run(AcceptWebSocketConnections);
                
                // Keep the application running
                while (_isRunning)
                {
                    await Task.Delay(1000);
                }
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Error starting agent: {ex.Message}");
            }
        }

        static async Task AcceptWebSocketConnections()
        {
            while (_isRunning)
            {
                try
                {
                    var context = await _httpListener.GetContextAsync();
                    if (context.Request.IsWebSocketRequest)
                    {
                        _ = Task.Run(() => HandleWebSocketConnection(context));
                    }
                    else
                    {
                        context.Response.StatusCode = 400;
                        context.Response.Close();
                    }
                }
                catch (Exception ex)
                {
                    if (_isRunning)
                        Console.WriteLine($"Error accepting connection: {ex.Message}");
                }
            }
        }

        static async Task HandleWebSocketConnection(HttpListenerContext context)
        {
            WebSocket webSocket = null;
            try
            {
                var webSocketContext = await context.AcceptWebSocketAsync(null);
                webSocket = webSocketContext.WebSocket;
                
                Console.WriteLine("Admin connected for screen monitoring");
                
                // Send initial handshake
                var handshake = new
                {
                    type = "handshake",
                    clientInfo = new
                    {
                        computerName = Environment.MachineName,
                        userName = Environment.UserName,
                        resolution = $"{Screen.PrimaryScreen.Bounds.Width}x{Screen.PrimaryScreen.Bounds.Height}",
                        captureResolution = $"{CAPTURE_WIDTH}x{CAPTURE_HEIGHT}",
                        fps = TARGET_FPS
                    }
                };
                
                await SendJsonMessage(webSocket, handshake);
                
                // Start screen capture timer
                _captureTimer = new System.Threading.Timer(
                    async _ => await CaptureAndSendScreen(webSocket), 
                    null, 
                    TimeSpan.Zero, 
                    TimeSpan.FromMilliseconds(1000.0 / TARGET_FPS)
                );
                
                // Keep connection alive and handle incoming messages
                var buffer = new byte[1024];
                while (webSocket.State == WebSocketState.Open)
                {
                    var result = await webSocket.ReceiveAsync(new ArraySegment<byte>(buffer), CancellationToken.None);
                    
                    if (result.MessageType == WebSocketMessageType.Text)
                    {
                        var message = Encoding.UTF8.GetString(buffer, 0, result.Count);
                        await HandleIncomingMessage(webSocket, message);
                    }
                    else if (result.MessageType == WebSocketMessageType.Close)
                    {
                        break;
                    }
                }
            }
            catch (Exception ex)
            {
                Console.WriteLine($"WebSocket error: {ex.Message}");
            }
            finally
            {
                _captureTimer?.Dispose();
                webSocket?.Dispose();
                Console.WriteLine("Admin disconnected");
            }
        }

        static async Task HandleIncomingMessage(WebSocket webSocket, string message)
        {
            try
            {
                dynamic msg = JsonConvert.DeserializeObject(message);
                string type = msg.type;
                
                switch (type)
                {
                    case "ping":
                        await SendJsonMessage(webSocket, new { type = "pong" });
                        break;
                }
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Error handling message: {ex.Message}");
            }
        }

        static async Task CaptureAndSendScreen(WebSocket webSocket)
        {
            if (webSocket.State != WebSocketState.Open) return;
            
            lock (_captureLock)
            {
                try
                {
                    byte[] screenData = CaptureScreen();
                    if (screenData != null)
                    {
                        var frameMessage = new
                        {
                            type = "frame",
                            timestamp = DateTimeOffset.UtcNow.ToUnixTimeMilliseconds(),
                            data = Convert.ToBase64String(screenData),
                            format = "jpeg",
                            width = CAPTURE_WIDTH,
                            height = CAPTURE_HEIGHT
                        };
                        
                        _ = Task.Run(async () =>
                        {
                            try
                            {
                                await SendJsonMessage(webSocket, frameMessage);
                            }
                            catch (Exception ex)
                            {
                                Console.WriteLine($"Error sending frame: {ex.Message}");
                            }
                        });
                    }
                }
                catch (Exception ex)
                {
                    Console.WriteLine($"Error capturing screen: {ex.Message}");
                }
            }
        }

        static byte[] CaptureScreen()
        {
            try
            {
                Rectangle bounds = Screen.PrimaryScreen.Bounds;
                
                using (Bitmap bitmap = new Bitmap(bounds.Width, bounds.Height))
                using (Graphics graphics = Graphics.FromImage(bitmap))
                {
                    graphics.CopyFromScreen(bounds.X, bounds.Y, 0, 0, bounds.Size, CopyPixelOperation.SourceCopy);
                    
                    // Resize to target resolution
                    using (Bitmap resized = new Bitmap(CAPTURE_WIDTH, CAPTURE_HEIGHT))
                    using (Graphics resizeGraphics = Graphics.FromImage(resized))
                    {
                        resizeGraphics.InterpolationMode = System.Drawing.Drawing2D.InterpolationMode.HighQualityBicubic;
                        resizeGraphics.DrawImage(bitmap, 0, 0, CAPTURE_WIDTH, CAPTURE_HEIGHT);
                        
                        // Convert to JPEG with compression
                        using (MemoryStream stream = new MemoryStream())
                        {
                            ImageCodecInfo jpegCodec = GetEncoder(ImageFormat.Jpeg);
                            if (jpegCodec != null)
                            {
                                EncoderParameters encoderParams = new EncoderParameters(1);
                                encoderParams.Param[0] = new EncoderParameter(System.Drawing.Imaging.Encoder.Quality, JPEG_QUALITY);
                                resized.Save(stream, jpegCodec, encoderParams);
                            }
                            else
                            {
                                resized.Save(stream, ImageFormat.Jpeg);
                            }
                            return stream.ToArray();
                        }
                    }
                }
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Screen capture error: {ex.Message}");
                return null;
            }
        }

        static ImageCodecInfo GetEncoder(ImageFormat format)
        {
            ImageCodecInfo[] codecs = ImageCodecInfo.GetImageDecoders();
            foreach (ImageCodecInfo codec in codecs)
            {
                if (codec.FormatID == format.Guid)
                    return codec;
            }
            return null;
        }

        static async Task SendJsonMessage(WebSocket webSocket, object message)
        {
            if (webSocket.State != WebSocketState.Open) return;
            
            string json = JsonConvert.SerializeObject(message);
            byte[] buffer = Encoding.UTF8.GetBytes(json);
            await webSocket.SendAsync(new ArraySegment<byte>(buffer), WebSocketMessageType.Text, true, CancellationToken.None);
        }

        static string GetLocalIPAddress()
        {
            try
            {
                string hostName = Dns.GetHostName();
                IPHostEntry hostEntry = Dns.GetHostEntry(hostName);
                
                foreach (IPAddress ip in hostEntry.AddressList)
                {
                    if (ip.AddressFamily == System.Net.Sockets.AddressFamily.InterNetwork && 
                        !IPAddress.IsLoopback(ip))
                    {
                        return ip.ToString();
                    }
                }
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Error getting IP address: {ex.Message}");
            }
            return "127.0.0.1";
        }

        static void Stop()
        {
            _isRunning = false;
            _captureTimer?.Dispose();
            _httpListener?.Stop();
            _httpListener?.Close();
        }
    }
}
