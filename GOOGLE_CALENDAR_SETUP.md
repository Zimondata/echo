# 📅 Google Calendar Integration Setup

## 🚀 Quick Setup Guide

### 1. Google Cloud Console Configuration

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Create a new project or select existing one
3. Enable Google Calendar API:
   - Go to **APIs & Services** → **Library**
   - Search for "Google Calendar API"
   - Click **Enable**

4. Create OAuth 2.0 Credentials:
   - Go to **APIs & Services** → **Credentials**
   - Click **+ CREATE CREDENTIALS** → **OAuth client ID**
   - Choose **Web application**
   - Set name: "Echo AI Assistant"
   - Add Authorized redirect URIs:
     - `http://localhost:3000/auth/google/callback` (development)
     - `https://yourdomain.com/auth/google/callback` (production)

5. Download credentials JSON or copy Client ID and Client Secret

### 2. Rails Configuration

Add Google credentials to Rails encrypted credentials:

```bash
rails credentials:edit
```

Add the following structure:

```yaml
google:
  client_id: YOUR_GOOGLE_CLIENT_ID
  client_secret: YOUR_GOOGLE_CLIENT_SECRET
  redirect_uri: http://localhost:3000/auth/google/callback
```

### 3. Test Configuration

Restart Rails server and test endpoints:

```bash
# Check Google connection status
curl http://localhost:3000/auth/google/status

# Check calendar sync stats  
curl http://localhost:3000/api/v1/calendar_events/sync_stats
```

## 🔗 OAuth Flow

### 1. Authorization URL
```http
GET /auth/google
```
Redirects user to Google for authorization

### 2. Callback Handling
```http
GET /auth/google/callback?code=...&state=...
```
Handles Google OAuth callback and stores tokens

### 3. Connection Status
```http
GET /auth/google/status
```
Returns current connection status

## 📊 API Endpoints

### Calendar Events

```http
# List calendar events
GET /api/v1/calendar_events

# Create calendar event (auto-syncs to Google)
POST /api/v1/calendar_events
{
  "calendar_event": {
    "title": "Meeting with client",
    "description": "Quarterly review",
    "start_time": "2025-10-14T10:00:00Z",
    "end_time": "2025-10-14T11:00:00Z"
  }
}

# Manual sync with Google Calendar
POST /api/v1/calendar_events/sync_google
{
  "direction": "full"  // "full", "to_google", "from_google"
}

# Get Google calendars list
GET /api/v1/calendar_events/google_calendars

# Get events from Google Calendar
GET /api/v1/calendar_events/google_events?start_date=2025-10-01&end_date=2025-10-31

# Sync statistics
GET /api/v1/calendar_events/sync_stats
```

### Google Auth Management

```http
# Disconnect Google Calendar
DELETE /auth/google/disconnect

# Manual sync trigger
POST /auth/google/sync
```

## 🔄 Automatic Sync

The system provides several levels of automatic synchronization:

### 1. Real-time Sync
- **Create**: New CalendarEvent → Google Calendar
- **Update**: Local changes → Google Calendar  
- **Delete**: Local deletion → Google Calendar deletion

### 2. Periodic Full Sync
- Runs every 4 hours for connected users
- Bidirectional sync (local ↔ Google)
- Handles conflicts by preferring most recent changes

### 3. Manual Sync
- On-demand full sync via API
- User-triggered sync from UI
- Useful for resolving sync issues

## 📝 Entry → Calendar Event Flow

When Telegram bot creates a "plan" type entry:

1. **AI Analysis** extracts dates and times from user message
2. **CalendarEvent** is created with extracted info
3. **Auto-sync** pushes event to Google Calendar (if connected)
4. **Reminder** is optionally created based on event timing

## 🛠 Troubleshooting

### Common Issues

**1. "Google Calendar not connected"**
- User needs to complete OAuth flow
- Check credentials configuration
- Verify redirect URI matches exactly

**2. "Token expired"** 
- Automatic refresh should handle this
- If persistent, user needs to re-authorize

**3. "Sync errors"**
- Check sync notifications in user settings
- View detailed errors in Rails logs
- Common causes: permissions, API limits

### Debug Commands

```bash
# Check Rails logs for sync errors
tail -f log/development.log | grep "Google"

# Test OAuth configuration
rails console
> Google::OauthService.new.authorization_url

# Check user's Google connection
rails console  
> user = User.first
> Google::OauthService.connected?(user)
```

### API Rate Limits

Google Calendar API limits:
- **100 queries per 100 seconds per user**
- **1,000 queries per 100 seconds**

The integration handles rate limits gracefully with exponential backoff retry logic.

## 🔐 Security Notes

- OAuth tokens are encrypted in database
- Refresh tokens allow continuous access
- Users can revoke access anytime via Google Account settings
- No sensitive calendar data is logged

## 🎯 Features

### ✅ Implemented
- [x] Complete OAuth 2.0 flow
- [x] Bidirectional calendar sync
- [x] Real-time event creation/updates
- [x] Automatic conflict resolution
- [x] Background sync jobs
- [x] Comprehensive API endpoints
- [x] Error handling and retry logic

### 🚧 Future Enhancements
- [ ] Multiple calendar support
- [ ] Calendar sharing and permissions
- [ ] Advanced recurrence rules
- [ ] Calendar notifications
- [ ] Meeting invite management

## 💡 Usage Examples

### Connect Google Calendar
1. User calls `/auth/google`
2. Completes OAuth flow
3. System starts automatic sync

### Create Event from Telegram
1. User: "Встреча с клиентом завтра в 15:00"
2. AI extracts: date="tomorrow", time="15:00"
3. Creates CalendarEvent
4. Auto-syncs to Google Calendar
5. Creates reminder 30 min before

### View Sync Status
```bash
curl http://localhost:3000/api/v1/calendar_events/sync_stats
```

Response:
```json
{
  "data": {
    "google_connected": true,
    "total_events": 25,
    "synced_events": 23,
    "unsynced_events": 2,
    "last_sync": "2025-10-13T14:30:00Z",
    "google_email": "user@gmail.com"
  }
}
```

---

🎉 **Google Calendar integration is now ready!** Users can seamlessly sync their AI-generated calendar events with Google Calendar for a unified scheduling experience.