const express = require('express');
const cors = require('cors');
const { createClient } = require('@supabase/supabase-js');
require('dotenv').config();

const app = express();
const PORT = process.env.PORT || 5000;

// Initialize Supabase Client instead of direct pg connection
// This bypasses the IPv4 deprecation on the raw Postgres port by using the robust REST API
const supabaseUrl = process.env.SUPABASE_URL || 'https://ycbxnrobtnrjrkyaltjr.supabase.co';
const supabaseKey = process.env.SUPABASE_KEY || 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InljYnhucm9idG5yanJreWFsdGpyIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzQ0NjAyNDAsImV4cCI6MjA5MDAzNjI0MH0.BKExjd9NoWx0A2FAYJIgSNvsqHnx13l5vYM5-hsBhno';
const supabase = createClient(supabaseUrl, supabaseKey);

// Middleware
app.use(cors());
app.use(express.json());

// Logger
app.use((req, res, next) => {
  console.log(`[${req.method}] ${req.url}`);
  next();
});

// ==========================================
// API ROUTES
// ==========================================

// Health Check
app.get('/health', (req, res) => {
  res.status(200).json({ status: 'UP', timestamp: new Date() });
});

// Authentication / Profile
app.get('/api/auth/profile/:userId', async (req, res) => {
  const { userId } = req.params;
  try {
    const { data: profile, error } = await supabase
      .from('profiles')
      .select('*')
      .eq('id', userId)
      .single();

    if (error || !profile) {
      return res.status(404).json({ success: false, message: 'User not found' });
    }
    
    res.status(200).json({ success: true, user: profile });
  } catch (err) {
    console.error('Profile Fetch Error:', err);
    res.status(500).json({ success: false, error: 'Database error' });
  }
});

// Pickups Routes
app.get('/api/pickups/:userId', async (req, res) => {
  const { userId } = req.params;
  try {
    const { data: pickups, error } = await supabase
      .from('pickups')
      .select('*')
      .eq('user_id', userId)
      .order('created_at', { ascending: false });

    if (error) throw error;
    res.status(200).json({ success: true, pickups });
  } catch (err) {
    console.error('Pickups Fetch Error:', err);
    res.status(500).json({ success: false, error: 'Database error' });
  }
});

app.post('/api/pickups/schedule', async (req, res) => {
  const { userId, date, wasteType, address, photoUrl } = req.body;
  
  if (!userId || !wasteType) {
    return res.status(400).json({ success: false, message: 'Missing required fields' });
  }

  try {
    const { data: pickup, error } = await supabase
      .from('pickups')
      .insert([{
        user_id: userId,
        date,
        waste_type: wasteType,
        address,
        status: 'scheduled',
        photo_url: photoUrl
      }])
      .select()
      .single();

    if (error) throw error;
    res.status(201).json({ success: true, pickup });
  } catch (err) {
    console.error('Schedule Pickup Error:', err);
    res.status(500).json({ success: false, error: 'Database error' });
  }
});

// Rewards Routes
app.get('/api/rewards', async (req, res) => {
  try {
    const { data: rewards, error } = await supabase
      .from('rewards')
      .select('*');

    if (error) throw error;
    res.status(200).json({ success: true, rewards: rewards || [] });
  } catch (err) {
    console.error('Rewards Fetch Error:', err);
    res.status(500).json({ success: false, error: 'Database error' });
  }
});

// Redeem Reward
app.post('/api/rewards/redeem', async (req, res) => {
  const { userId, rewardId, pointsCost } = req.body;

  if (!userId || !pointsCost) {
    return res.status(400).json({ success: false, message: 'Missing required fields' });
  }

  try {
    // Check user balance
    const { data: profile, error: profileErr } = await supabase
      .from('profiles')
      .select('eco_points')
      .eq('id', userId)
      .single();

    if (profileErr || !profile) {
      return res.status(404).json({ success: false, message: 'User not found' });
    }

    const currentPoints = profile.eco_points || 0;
    if (currentPoints < pointsCost) {
      return res.status(400).json({ success: false, message: 'Insufficient points' });
    }

    // Deduct points
    const { error: updateErr } = await supabase
      .from('profiles')
      .update({ eco_points: currentPoints - pointsCost })
      .eq('id', userId);

    if (updateErr) throw updateErr;

    res.status(200).json({ success: true, message: 'Reward redeemed', newBalance: currentPoints - pointsCost });
  } catch (err) {
    console.error('Redeem Reward Error:', err);
    res.status(500).json({ success: false, error: 'Database error' });
  }
});

// Leaderboard
app.get('/api/leaderboard', async (req, res) => {
  try {
    const { data: leaderboard, error } = await supabase
      .from('profiles')
      .select('id, full_name, eco_points, co2_saved')
      .order('eco_points', { ascending: false })
      .limit(20);

    if (error) throw error;
    res.status(200).json({ success: true, leaderboard: leaderboard || [] });
  } catch (err) {
    console.error('Leaderboard Fetch Error:', err);
    res.status(500).json({ success: false, error: 'Database error' });
  }
});

// Report Issue
app.post('/api/reports', async (req, res) => {
  const { userId, issueType, location, description, photoUrl } = req.body;

  if (!issueType || !location) {
    return res.status(400).json({ success: false, message: 'Missing required fields' });
  }

  try {
    const { data: report, error } = await supabase
      .from('reports')
      .insert([{
        user_id: userId,
        issue_type: issueType,
        location,
        description,
        photo_url: photoUrl,
        status: 'pending'
      }])
      .select()
      .single();

    if (error) throw error;
    res.status(201).json({ success: true, report });
  } catch (err) {
    console.error('Report Issue Error:', err);
    res.status(500).json({ success: false, error: 'Database error' });
  }
});

// Update Profile
app.put('/api/auth/profile/:userId', async (req, res) => {
  const { userId } = req.params;
  const { full_name, latitude, longitude } = req.body;

  try {
    const updates = {};
    if (full_name !== undefined) updates.full_name = full_name;
    if (latitude !== undefined) updates.latitude = latitude;
    if (longitude !== undefined) updates.longitude = longitude;

    if (Object.keys(updates).length === 0) {
      return res.status(400).json({ success: false, message: 'No fields to update' });
    }

    const { data: updatedUser, error } = await supabase
      .from('profiles')
      .update(updates)
      .eq('id', userId)
      .select()
      .single();

    if (error) {
       if (error.code === 'PGRST116') {
           return res.status(404).json({ success: false, message: 'User not found' });
       }
       throw error;
    }

    res.status(200).json({ success: true, user: updatedUser });
  } catch (err) {
    console.error('Update Profile Error:', err);
    res.status(500).json({ success: false, error: 'Database error' });
  }
});

// Start Server
app.listen(PORT, '0.0.0.0', () => {
  console.log(`=========================================`);
  console.log(`🌿 Global Coolers REST API Running on port ${PORT}`);
  console.log(`=========================================`);
});
