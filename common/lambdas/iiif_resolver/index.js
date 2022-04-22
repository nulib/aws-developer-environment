const handler = (event, _context) => {
  const { request } = event.Records[0].cf;
  const path = decodeURI(request.uri.replace(/%2f/gi, ''));
  const [prefix, poster, id] = path.match(/^\/iiif\/2\/([^/]+)\/(posters\/)?([^/]+)/).slice(-3);
  const pairtree = id.match(/.{1,2}/g).join('/');
  const tiffBucket = [prefix, "pyramids"].join("-");
  const s3Location = poster ? `s3://${tiffBucket}/posters/${pairtree}-poster.tif` : `s3://${tiffBucket}/${pairtree}-pyramid.tif`;
  request.headers['x-preflight-location'] = [{ key: 'X-Preflight-Location', value: s3Location }];
  return request;
}
