const localtunnel = require('localtunnel');
const port = 3000;
const REQUIRED_SUBDOMAIN = 'smart-transit-v1-dev';
const REQUIRED_URL = `https://${REQUIRED_SUBDOMAIN}.loca.lt`;

console.log('Attempting to start tunnel on port', port, '...');
console.log(`Target URL: ${REQUIRED_URL}`);

(async () => {
  try {
    const tunnel = await localtunnel({ port, subdomain: REQUIRED_SUBDOMAIN });

    // GUARD: If localtunnel gave us a different URL, abort immediately
    if (tunnel.url !== REQUIRED_URL) {
      console.error('-----------------------------------');
      console.error('  ❌ TUNNEL URL MISMATCH!');
      console.error(`  Expected : ${REQUIRED_URL}`);
      console.error(`  Got      : ${tunnel.url}`);
      console.error('-----------------------------------');
      console.error('The subdomain is temporarily taken on localtunnel servers.');
      console.error('Please wait 30 seconds and run `npm run tunnel` again.');
      tunnel.close();
      process.exit(1);
    }

    console.log('-----------------------------------');
    console.log('  SmartTransit Public Tunnel');
    console.log('  Status: ACTIVE ✅');
    console.log('  URL: ' + tunnel.url);
    console.log('-----------------------------------');
    console.log('Keep this terminal open!');

    tunnel.on('close', () => {
      console.log('Tunnel closed. Run `npm run tunnel` to restart.');
    });

    tunnel.on('error', (err) => {
      console.error('Tunnel error:', err.message);
    });

  } catch (err) {
    console.error('Failed to start tunnel:', err.message);
    console.log('TIP: Check if your local server is running on port 3000.');
  }
})();
