function viewerRequest(event) {
  const request = event.request;
  const path = decodeURI(request.uri.replace(/%2f/gi, ""));
  const matches = path
    .match(/^\/iiif\/(2|3)\/([^/]+)\/(posters\/)?([^/]+)/)
    .slice(-3);
  const prefix = matches[0];
  const poster = matches[1];
  const id = matches[2];
  const pairtree = id.match(/.{1,2}/g).join("/");
  const tiffBucket = [prefix, "pyramids"].join("-");
  const s3Location = poster
    ? `s3://${tiffBucket}/posters/${pairtree}-poster.tif`
    : `s3://${tiffBucket}/${pairtree}-pyramid.tif`;
  request.headers["x-preflight-location"] = { value: s3Location };
  // request.uri = path.replace(`/${prefix}`, "");
  return request;
}

function viewerResponse(event) {
  const request = event.request;
  const response = event.response;
  let origin = "*";
  if (request.headers.origin) {
    origin = request.headers.origin.value;
  }
  response.headers["access-control-allow-origin"] = { value: origin };
  response.headers["access-control-allow-headers"] = {
    value: "authorization, cookie"
  };
  response.headers["access-control-allow-credentials"] = { value: "true" };
  return response;
}

function handler(event) {
  switch (event.context.eventType) {
    case "viewer-request":
      return viewerRequest(event);
    case "viewer-response":
      return viewerResponse(event);
    default:
      return event;
  }
}
