// sample_send_fcm.js
// Node.js script to send an FCM message to a token or topic.
// Usage: node sample_send_fcm.js <SERVER_KEY> <TOKEN_OR_TOPIC>

const fetch = require('node-fetch');
const serverKey = process.argv[2];
const to = process.argv[3];

if (!serverKey || !to) {
  console.error('Usage: node sample_send_fcm.js <SERVER_KEY> <TOKEN_OR_TOPIC>');
  process.exit(1);
}

const payload = {
  to,
  notification: {
    title: 'Healthmate Alert',
    body: 'This is a test critical health advisory.'
  },
  data: { urgent: 'true' }
};

fetch('https://fcm.googleapis.com/fcm/send', {
  method: 'POST',
  headers: {
    'Content-Type': 'application/json',
    'Authorization': 'key=' + serverKey
  },
  body: JSON.stringify(payload)
}).then(res => res.json()).then(console.log).catch(console.error);
