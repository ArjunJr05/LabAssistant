# Admin Logout - Automatic Student Logout Feature

## Overview
When an admin logs out, all connected students are automatically logged out and redirected to the login screen.

## Implementation Summary

### 1. **Backend - Admin Broadcast Endpoint** ✅
**File:** `backend/routes/admin.js`

Added new endpoint `/api/admin/broadcast-logout`:
- Broadcasts `admin-shutdown` event via Socket.IO to all connected clients
- Sets all students offline in the database
- Returns count of affected students

### 2. **Flutter Auth Service** ✅
**File:** `lib/services/auth_service.dart`

Updated `logout()` method:
- When admin logs out, calls `/api/admin/broadcast-logout` endpoint
- Broadcasts shutdown notification to all students via Socket.IO
- Stops the Node.js server after broadcasting

### 3. **Student Screen Listener** ✅
**File:** `lib/screens/students_screen.dart`

Updated `_showAdminShutdownDialog()`:
- Listens for `admin-shutdown` Socket.IO event
- Shows dialog informing student of admin logout
- **Automatically logs out the student** by calling `authService.logout()`
- Redirects to login screen after logout

### 4. **Socket Service** ✅
**File:** `lib/services/socket_services.dart`

Already has built-in support for:
- `admin-shutdown` event listener (line 115-134)
- `force-disconnect` event listener (line 137-153)
- Auto-disconnect after receiving shutdown notification

## How It Works

### Flow Diagram
```
Admin Logs Out
    ↓
AuthService.logout() called
    ↓
POST /api/admin/broadcast-logout
    ↓
Backend emits 'admin-shutdown' via Socket.IO
    ↓
All Student Apps receive 'admin-shutdown' event
    ↓
Student Screen shows dialog
    ↓
Student clicks "OK"
    ↓
Student AuthService.logout() called
    ↓
Student redirected to login screen
```

### Technical Details

**Admin Side:**
1. Admin clicks logout
2. `AuthService.logout()` detects admin role
3. Calls `POST /api/admin/broadcast-logout` with message
4. Backend broadcasts to all Socket.IO clients
5. Sets all students offline in database
6. Stops Node.js server

**Student Side:**
1. Socket service receives `admin-shutdown` event
2. `_showAdminShutdownDialog()` is triggered
3. Dialog shows: "Admin has logged out. You will be automatically logged out..."
4. When student clicks "OK":
   - `await _authService?.logout()` is called
   - Student's session is cleared
   - Redirected to `/role-selection` route

## Key Files Modified

1. ✅ `lib/services/auth_service.dart` - Admin logout broadcast logic
2. ✅ `lib/screens/students_screen.dart` - Student auto-logout on admin shutdown
3. ✅ `backend/routes/admin.js` - New `/broadcast-logout` endpoint
4. ✅ `lib/services/socket_services.dart` - Already had shutdown listeners

## Testing Checklist

- [ ] Admin logs out → All students receive shutdown notification
- [ ] Student sees dialog with logout message
- [ ] Student clicks "OK" → Automatically logged out
- [ ] Student redirected to login screen
- [ ] Student cannot access dashboard after admin logout
- [ ] Database shows all students offline after admin logout
- [ ] Server stops after admin logout

## API Endpoints

### POST `/api/admin/broadcast-logout`
**Auth Required:** Yes (Admin only)

**Request Body:**
```json
{
  "message": "Admin has logged out. All students will be logged out.",
  "timestamp": "2025-10-30T10:23:21+05:30"
}
```

**Response:**
```json
{
  "success": true,
  "message": "Admin logout broadcast sent successfully",
  "studentsAffected": 5
}
```

## Socket.IO Events

### Event: `admin-shutdown`
**Emitted by:** Backend when admin logs out
**Received by:** All connected student clients

**Payload:**
```json
{
  "message": "Admin has logged out. All students will be logged out.",
  "timestamp": "2025-10-30T10:23:21+05:30",
  "reason": "admin_logout"
}
```

## Security Considerations

- ✅ Only admin can trigger broadcast logout
- ✅ Students are forcefully logged out (cannot bypass)
- ✅ Database updated to mark all students offline
- ✅ Server stops to prevent unauthorized access
- ✅ Student sessions cleared from local storage

## Future Enhancements

- Add countdown timer before auto-logout (e.g., "Logging out in 5 seconds...")
- Log admin logout events for audit trail
- Send notification to students before admin logs out
- Allow admin to send custom message to students

## Notes

- The Socket.IO service already had excellent shutdown handling built-in
- The main change was ensuring students actually call `logout()` instead of just redirecting
- This ensures proper cleanup of student sessions and local storage
