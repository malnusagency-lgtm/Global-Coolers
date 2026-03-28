const { createClient } = require('@supabase/supabase-js');
require('dotenv').config();

const supabaseUrl = process.env.SUPABASE_URL || 'https://ycbxnrobtnrjrkyaltjr.supabase.co';
const supabaseKey = process.env.SUPABASE_KEY || 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InljYnhucm9idG5yanJreWFsdGpyIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzQ0NjAyNDAsImV4cCI6MjA5MDAzNjI0MH0.BKExjd9NoWx0A2FAYJIgSNvsqHnx13l5vYM5-hsBhno';
const supabase = createClient(supabaseUrl, supabaseKey);

const rewards = [
  { partner: 'Safaricom / Airtel', title: '100 KES Airtime', cost: 500, status: 'active' },
  { partner: 'K-Gas 6kg Cylinder', title: '10% Off Refill', cost: 1000, status: 'active' },
  { partner: 'Naivas Supermarket', title: 'Shopping Voucher', cost: 2500, status: 'active' },
  { partner: 'Java House', title: 'Free Coffee', cost: 300, status: 'active' },
  { partner: 'Karura Forest', title: 'Donate a Tree', cost: 150, status: 'active' },
  { partner: 'Made in Kibera', title: 'Eco Tote Bag', cost: 800, status: 'active' }
];

async function seedRewards() {
  try {
    for (const reward of rewards) {
      const { error } = await supabase
        .from('rewards')
        .insert([reward]);
      if (error) throw error;
    }
    console.log('Rewards seeded successfully.');
  } catch (err) {
    console.error('Error seeding rewards:', err);
  }
}

seedRewards();
