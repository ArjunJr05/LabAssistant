// Script to update hardcoded paths to relative paths for deployment
// Run this before building the installer

import 'dart:io';

void main() async {
  print('🔧 Updating paths for deployment...\n');
  
  // 1. Update server_manager.dart
  await updateServerManager();
  
  // 2. Update login_screen.dart
  await updateLoginScreen();
  
  // 3. Create updated compiler.js
  await updateCompilerJs();
  
  print('\n✅ All paths updated successfully!');
  print('📝 Please review the changes before building the installer.');
}

Future<void> updateServerManager() async {
  print('📄 Updating server_manager.dart...');
  
  final file = File('lib/services/server_manager.dart');
  var content = await file.readAsString();
  
  // Replace hardcoded path with relative path
  final oldPath = r"final backendPath = Platform.isWindows ? r'C:\Users\user\labassistant\backend' : '/Users/user/labassistant/backend';";
  final newPath = r'''// Get the directory where the executable is located
      final executableDir = File(Platform.resolvedExecutable).parent.path;
      final backendPath = Platform.isWindows 
          ? '$executableDir\\backend'
          : '$executableDir/backend';''';
  
  if (content.contains(oldPath)) {
    content = content.replaceAll(oldPath, newPath);
    await file.writeAsString(content);
    print('   ✅ Updated server_manager.dart');
  } else {
    print('   ⚠️  Pattern not found in server_manager.dart - may already be updated');
  }
}

Future<void> updateLoginScreen() async {
  print('📄 Updating login_screen.dart...');
  
  final file = File('lib/screens/login_screen.dart');
  var content = await file.readAsString();
  
  // Replace hardcoded path with relative path
  final oldPath = r"const agentPath = r'C:\Users\arjun\LabAssistant\screen_capture_agent\dist\ScreenCaptureAgent.exe';";
  final newPath = r'''// Get the directory where the executable is located
    final executableDir = File(Platform.resolvedExecutable).parent.path;
    final agentPath = Platform.isWindows
        ? '$executableDir\\screen_capture_agent\\dist\\ScreenCaptureAgent.exe'
        : '$executableDir/screen_capture_agent/dist/ScreenCaptureAgent';''';
  
  if (content.contains(oldPath)) {
    content = content.replaceAll(oldPath, newPath);
    await file.writeAsString(content);
    print('   ✅ Updated login_screen.dart');
  } else {
    print('   ⚠️  Pattern not found in login_screen.dart - may already be updated');
  }
}

Future<void> updateCompilerJs() async {
  print('📄 Creating deployment version of compiler.js...');
  
  final file = File('backend/utils/compiler.js');
  var content = await file.readAsString();
  
  // Replace hardcoded MinGW path with relative path
  final oldPath = "const MINGW_PATH = 'C:\\\\Users\\\\user\\\\LabAssistant\\\\MinGW\\\\bin\\\\gcc.exe';";
  final newPath = '''// Get MinGW path relative to backend directory
const path = require('path');
const MINGW_PATH = path.join(__dirname, '..', '..', 'MinGW', 'bin', 'gcc.exe');''';
  
  if (content.contains(oldPath)) {
    content = content.replaceAll(oldPath, newPath);
    
    // Create backup
    final backupFile = File('backend/utils/compiler.js.backup');
    await backupFile.writeAsString(await File('backend/utils/compiler.js').readAsString());
    
    await file.writeAsString(content);
    print('   ✅ Updated compiler.js (backup created)');
  } else {
    print('   ⚠️  Pattern not found in compiler.js - may already be updated');
  }
}
