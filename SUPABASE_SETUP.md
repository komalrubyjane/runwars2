# Supabase Integration Setup Guide

## Overview
This document explains how to set up Supabase for the RunFlutterRun app with authentication, database, and real-time leaderboard features.

## Step 1: Create Supabase Project

1. Go to [supabase.com](https://supabase.com)
2. Sign up or log in
3. Create a new project:
   - Click "New Project"
   - Enter project name: "runflutterrun"
   - Choose a password (save it)
   - Select your region
   - Click "Create new project"

4. Wait for the project to be created (5-10 minutes)

## Step 2: Get Your Supabase Credentials

1. Go to **Settings > API** in your Supabase dashboard
2. You'll see:
   - **Project URL**: `https://your-project.supabase.co`
   - **Anon Key**: `your-anon-key`

3. Copy these and save them

## Step 3: Update Configuration in Flutter App

Open `lib/main.dart` and update the Supabase initialization:

```dart
await Supabase.initialize(
  url: 'https://your-project.supabase.co',  // Replace with your URL
  anonKey: 'your-anon-key',                  // Replace with your key
);
```

Also update `lib/core/services/supabase_service.dart`:

```dart
Future<void> initialize() async {
  await Supabase.initialize(
    url: 'https://your-project.supabase.co',  // Replace with your URL
    anonKey: 'your-anon-key',                  // Replace with your key
  );
  _client = Supabase.instance.client;
}
```

## Step 4: Create Database Tables

Go to your Supabase dashboard and go to **SQL Editor**. Run the following SQL queries:

### 1. Create Users Table

```sql
CREATE TABLE public.users (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email TEXT UNIQUE,
  full_name TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
  total_distance DOUBLE PRECISION DEFAULT 0,
  total_steps INTEGER DEFAULT 0,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can read their own profile"
  ON public.users FOR SELECT
  USING (auth.uid() = id);

CREATE POLICY "Users can update their own profile"
  ON public.users FOR UPDATE
  USING (auth.uid() = id);
```

### 2. Create Activities Table

```sql
CREATE TABLE public.activities (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  distance DOUBLE PRECISION NOT NULL,
  steps INTEGER NOT NULL,
  duration_seconds INTEGER NOT NULL,
  path_points JSONB,
  date DATE DEFAULT CURRENT_DATE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

ALTER TABLE public.activities ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can read their own activities"
  ON public.activities FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own activities"
  ON public.activities FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- Index for leaderboard queries
CREATE INDEX activities_date_distance_idx 
  ON public.activities(date DESC, distance DESC);
```

### 3. Enable Authentication Methods

In Supabase dashboard:
1. Go to **Authentication > Providers**
2. Make sure **Email** is enabled
3. (Optional) Enable other providers like Google, Apple, etc.

## Step 5: Set Up Row Level Security (RLS)

The tables already have basic RLS policies. For the leaderboard, users need to read other users' activities. Update the activities policy:

```sql
-- Allow reading all activities for leaderboard
CREATE POLICY "Anyone can read activities for leaderboard"
  ON public.activities FOR SELECT
  USING (TRUE);
```

## Step 6: Test the Setup

1. Run the app: `flutter run`
2. Try to register a new account
3. Check Supabase dashboard **Database > users** to verify user was created
4. Start a run/activity
5. Check **activities** table to verify activity was saved
6. Visit the Leaderboard screen to see real-time data

## API Reference

### Authentication

```dart
// Sign up
final response = await supabaseService.signUp(
  email: 'user@example.com',
  password: 'password123',
  fullName: 'John Doe',
);

// Sign in
final response = await supabaseService.signIn(
  email: 'user@example.com',
  password: 'password123',
);

// Sign out
await supabaseService.signOut();

// Get current user
final user = supabaseService.currentUser;
```

### Activities

```dart
// Save activity
await supabaseService.saveActivity(
  userId: 'user-id',
  distance: 5.2,
  steps: 6500,
  durationSeconds: 1800,
  pathPoints: [
    {'latitude': 37.7749, 'longitude': -122.4194, 'timestamp': '2024-02-04T10:30:00Z'},
    // ... more points
  ],
);

// Get user's activities
final activities = await supabaseService.getUserActivities('user-id');

// Get daily leaderboard
final leaderboard = await supabaseService.getDailyLeaderboard();
```

## Troubleshooting

### "Connection refused" error
- Make sure your Supabase project is created and running
- Verify your URL and Anon Key are correct

### "Permission denied" errors
- Check that RLS policies are properly set
- Verify the user is authenticated

### Activities not saving
- Check that the user exists in the `users` table
- Verify `user_id` matches the authenticated user's ID

### Leaderboard showing no data
- Make sure activities exist for today's date
- Check the `date` field in activities table

## Next Steps

1. Add profile pictures using Supabase Storage
2. Implement social features (following, likes)
3. Add historical leaderboards (weekly, monthly)
4. Set up real-time subscriptions for live leaderboard updates
5. Add analytics dashboard

## Additional Resources

- [Supabase Documentation](https://supabase.com/docs)
- [Flutter Guide](https://supabase.com/docs/guides/getting-started/tutorials/flutter)
- [SQL Documentation](https://supabase.com/docs/guides/database/overview)
