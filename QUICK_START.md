# Quick Start Guide: Supabase + Polyline Integration

## What You Now Have

✅ **Real-time Authentication** - Email/password signup and login via Supabase
✅ **Cloud Database** - Users and activities stored securely in Supabase
✅ **Polyline Maps** - Blue route lines showing user's travel path on Google Maps
✅ **Daily Leaderboard** - Real-time rankings of users by distance traveled
✅ **Activity Tracking** - Complete activity details including path coordinates stored in cloud

## Quick Setup (5 Minutes)

### Step 1: Get Supabase Credentials
1. Visit [supabase.com](https://supabase.com)
2. Create new project
3. Go to Settings > API
4. Copy your **Project URL** and **Anon Key**

### Step 2: Update Your App
Replace these values in TWO files:

**File 1: `lib/main.dart`** (around line 30)
```dart
await Supabase.initialize(
  url: 'https://your-project.supabase.co',  // ← Paste URL here
  anonKey: 'your-anon-key',                  // ← Paste key here
);
```

**File 2: `lib/core/services/supabase_service.dart`** (around line 20)
```dart
Future<void> initialize() async {
  await Supabase.initialize(
    url: 'https://your-project.supabase.co',  // ← Paste URL here
    anonKey: 'your-anon-key',                  // ← Paste key here
  );
}
```

### Step 3: Create Database Tables
1. In Supabase dashboard, go to **SQL Editor**
2. Copy-paste all SQL from `SUPABASE_SETUP.md` Section "Step 4"
3. Execute each query

### Step 4: Run the App
```bash
flutter run
```

## Using the Features

### 1. Sign Up / Log In
- Open app → click "Register" or "Login"
- Use Supabase email authentication
- Your profile is automatically created

### 2. Record Activity with Polyline
- Go to "Record" tab
- Tap "Start"
- Walk around (polyline tracks your path in real-time)
- Polyline = blue line connecting GPS points
- Tap "Save" when done

### 3. View Your Travel Route
- Activity map shows blue polyline
- Each GPS point is a vertex on the line
- Path is saved to Supabase database

### 4. Check Daily Leaderboard
- Go to "Leaderboard" tab
- See top users by distance today
- Medals: 🥇 1st, 🥈 2nd, 🥉 3rd
- Data updates in real-time from Supabase

## Architecture Overview

```
┌─────────────────────────────────────────┐
│      Flutter App (Your Phone)           │
├─────────────────────────────────────────┤
│  Location Provider (GPS) → Polyline     │
│  Auth Provider (Supabase Auth)          │
│  Activity Repository (Save/Fetch)       │
└──────────────┬──────────────────────────┘
               │
               │ (HTTPS/WebSocket)
               ↓
┌─────────────────────────────────────────┐
│     Supabase Cloud (Backend)            │
├─────────────────────────────────────────┤
│  📊 Database:                           │
│    ├── users table (profiles)           │
│    └── activities table (routes)        │
│                                         │
│  🔐 Authentication (Email/Password)     │
│  🔒 Row Level Security (Privacy)        │
└─────────────────────────────────────────┘
```

## Key Files

| File | Purpose |
|------|---------|
| `lib/core/services/supabase_service.dart` | Main Supabase client & operations |
| `lib/main.dart` | App initialization with Supabase |
| `lib/presentation/common/location/widgets/location_map.dart` | Polyline rendering |
| `lib/presentation/common/location/view_model/location_view_model.dart` | GPS tracking & saving |
| `lib/presentation/common/leaderboard/leaderboard_screen.dart` | Daily leaderboard UI |

## Polyline Explained

**How it works:**
1. User starts recording activity
2. GPS points collected every 1 second (1 meter precision)
3. Each point added to `LocationState.savedPositions`
4. Map draws line between consecutive points = **polyline**
5. Blue line grows in real-time as user walks
6. When activity saved, all points stored in Supabase

**Code location:**
- Polyline drawing: `location_map.dart` lines 35-43
- GPS collection: `location_view_model.dart` lines 60-140
- Saving to DB: `location_view_model.dart` lines 286-310

## Common Tasks

### Get User's Activities
```dart
final activities = await supabaseService.getUserActivities(userId);
```

### Get Daily Leaderboard
```dart
final leaderboard = await supabaseService.getDailyLeaderboard();
```

### Save Activity
```dart
await locationViewModel.saveActivityToSupabase(
  userId: currentUserId,
  distance: 5.2,
  durationSeconds: 1800,
);
```

## Troubleshooting

| Problem | Solution |
|---------|----------|
| Polyline not showing | Check GPS is enabled, walk around to generate points |
| Activities not saving | Verify Supabase URL/key are correct |
| Leaderboard empty | Make sure activities exist for today |
| Auth not working | Verify email provider enabled in Supabase |

## Database Schema

### users table
```
id (UUID) - User ID from Auth
email (TEXT) - User email
full_name (TEXT) - User's name
total_distance (DOUBLE) - km walked
total_steps (INT) - Steps counted
created_at (TIMESTAMP) - Join date
```

### activities table
```
id (UUID) - Activity ID
user_id (UUID) - User who did activity
distance (DOUBLE) - km traveled
steps (INT) - Steps taken
duration_seconds (INT) - Total time
path_points (JSONB) - Array of coordinates
  [
    {latitude, longitude, timestamp},
    ...
  ]
date (DATE) - Activity date
created_at (TIMESTAMP) - Record time
```

## Next Steps

1. ✅ Set up Supabase (5 min)
2. ✅ Update credentials (2 min)
3. ✅ Create tables (5 min)
4. ✅ Run app (2 min)
5. 🔄 Test all features
6. (Optional) Add more features:
   - Real-time leaderboard updates
   - Activity sharing
   - Social features
   - Achievement badges

## Need Help?

- **Supabase Issues**: Check [supabase.com/docs](https://supabase.com/docs)
- **Polyline Not Working**: Verify GPS permissions in Android/iOS settings
- **Build Errors**: Run `flutter clean && flutter pub get`

---

**Ready to go!** 🚀
