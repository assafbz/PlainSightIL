const http = require('http');

function getSupportedDatasets() {
  const options = {
    hostname: 'localhost',
    port: 8081,
    path: '/v1/projects/demo-plainsightil/databases/(default)/documents/datasets_metadata',
    method: 'GET'
  };

  const req = http.request(options, (res) => {
    let data = '';
    res.on('data', (chunk) => {
      data += chunk;
    });

    res.on('end', () => {
      try {
        const json = JSON.parse(data);
        const docs = json.documents || [];
        const supported = [];
        for (const doc of docs) {
          const fields = doc.fields || {};
          const isSupported = fields.isSupported && fields.isSupported.booleanValue;
          if (isSupported) {
            supported.push({
              id: fields.id ? fields.id.stringValue : doc.name.split('/').pop(),
              name: fields.name ? fields.name.stringValue : 'unknown',
              title: fields.title ? fields.title.stringValue : 'unknown',
              isSupported: isSupported
            });
          }
        }
        console.log(`Found ${supported.length} supported datasets:`);
        console.log(JSON.stringify(supported, null, 2));
      } catch (e) {
        console.error('Error parsing response:', e);
      }
    });
  });

  req.on('error', (e) => {
    console.error(`Problem with request: ${e.message}`);
  });

  req.end();
}

getSupportedDatasets();
