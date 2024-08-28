const getEventHeader = (request, name) => {
  if (request.headers && request.headers[name] && request.headers[name].length > 0) {
    return request.headers[name][0].value;
  } else {
    return undefined;
  }
};

const viewerRequest = (event) => {
  const { request } = event.Records[0].cf;
  const path = decodeURI(request.uri.replace(/%2f/gi, ''));
  const [prefix, poster, id] = path.match(/^\/iiif\/(2|3)\/([^/]+)\/(posters\/)?([^/]+)/).slice(-3);
  const pairtree = id.match(/.{1,2}/g).join('/');
  const tiffBucket = [prefix, "pyramids"].join("-");
  const s3Location = poster ? `s3://${tiffBucket}/posters/${pairtree}-poster.tif` : `s3://${tiffBucket}/${pairtree}-pyramid.tif`;
  request.headers['x-preflight-location'] = [{
    key: 'X-Preflight-Location',
    value: s3Location
  }];
  return request;
};

const viewerResponse = (event) => {
  const { request, response } = event.Records[0].cf;
  const origin = getEventHeader(request, 'origin') || '*';
  response.headers['access-control-allow-origin'] = [{ key: 'Access-Control-Allow-Origin', value: origin }];
  response.headers['access-control-allow-headers'] = [{ key: 'Access-Control-Allow-Headers', value: 'authorization, cookie' }];
  response.headers['access-control-allow-credentials'] = [{ key: 'Access-Control-Allow-Credentials', value: 'true' }];
  return response;
};

const handler = async (event, _context) => {
  const { eventType } = event.Records[0].cf.config;
  switch (eventType) {
    case "viewer-request": return viewerRequest(event);
    case "viewer-response": return viewerResponse(event);
    default: return event;
  }
};

module.exports = { handler }
