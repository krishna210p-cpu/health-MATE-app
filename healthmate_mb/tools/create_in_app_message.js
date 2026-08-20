/**
 * Node.js script to create an in_app_messages document in Firestore.
 * Usage:
 *   1. Install dependencies: npm install firebase-admin
 *   2. Set GOOGLE_APPLICATION_CREDENTIALS to your service account JSON file
 *   3. Run: node create_in_app_message.js [trigger] [title] [body]
 * Example:
 *   node create_in_app_message.js app_start "Hello!" "Welcome back! We're glad you're here."
 */

const admin = require('firebase-admin');

async function main() {
  try {
    // Initialize using default credentials (use GOOGLE_APPLICATION_CREDENTIALS env var)
    admin.initializeApp({});
    const db = admin.firestore();

    const trigger = process.argv[2] || 'app_start';
    const title = process.argv[3] || 'Hello!';
    const body = process.argv[4] || "Welcome back! We're glad you're here.";

    const doc = {
      active: true,
      trigger: trigger, // 'app_start' or 'first_open'
      title: title,
      body: body,
      targetAll: true,
      // Optionally list Android/iOS package ids to target specific apps
      targetApps: ['com.example.healthmate_mb', 'com.example.healthmate', 'com.example.healthmate_plus'],
      start_at: new Date().toISOString(),
      end_at: null,
      action_url: '',
      action_text: '',
      show_always: false
    };

    const ref = await db.collection('in_app_messages').add(doc);
    console.log('Created in_app_messages doc:', ref.id);
    process.exit(0);
  } catch (err) {
    console.error('Failed to create in_app_messages document:', err);
    process.exit(1);
  }
}

main();
