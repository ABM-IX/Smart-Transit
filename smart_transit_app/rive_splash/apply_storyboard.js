const fs = require('fs');
const path = require('path');
const file = path.join(__dirname, 'scene.rml');
let s = fs.readFileSync(file, 'utf8');
function addNodeFill(name, fillName, id) {
  if (s.includes('id="' + id + '"')) return;
  const re = new RegExp('(<Shape[^>]*name="' + name + '"[^>]*>[\\s\\S]*?<Fill name="Fill"><SolidColor )colorValue="FF0A66C2" name="Cerulean"(/>)');
  s = s.replace(re, '$1colorValue="FF0F1B2E" name="' + fillName + '" id="' + id + '"$2');
}
addNodeFill('Node1', 'Node1Navy', '0:241');
addNodeFill('Node2', 'Node2Navy', '0:231');
addNodeFill('Node3', 'Node3Navy', '0:221');
const trace = [
'<LinearAnimation duration="105" name="TraceAndConnect" id="0:52">',
'  <KeyedObject objectId="0:211"><KeyedProperty propertyKey="115"><KeyFrameDouble value="0" frame="0" interpolationType="cubic"><CubicEaseInterpolator x1="0.32" y1="0" x2="0.18" y2="1"/></KeyFrameDouble><KeyFrameDouble value="1" frame="105" interpolationType="cubic"><CubicEaseInterpolator x1="0.22" y1="0" x2="0.25" y2="1"/></KeyFrameDouble></KeyedProperty></KeyedObject>',
'  <KeyedObject objectId="0:220"><KeyedProperty propertyKey="16"><KeyFrameDouble value="1" frame="0"/><KeyFrameDouble value="1" frame="22"/><KeyFrameDouble value="0.06" frame="27" interpolationType="cubic"/><KeyFrameDouble value="1.12" frame="31" interpolationType="cubic"/><KeyFrameDouble value="1" frame="36"/></KeyedProperty><KeyedProperty propertyKey="17"><KeyFrameDouble value="1" frame="0"/><KeyFrameDouble value="1.08" frame="31"/><KeyFrameDouble value="1" frame="36"/></KeyedProperty></KeyedObject>',
'  <KeyedObject objectId="0:221"><KeyedProperty propertyKey="37"><KeyFrameColor value="FF0F1B2E" frame="0"/><KeyFrameColor value="FF0F1B2E" frame="25"/><KeyFrameColor value="FF22C8FF" frame="31"/><KeyFrameColor value="FF22C8FF" frame="105"/></KeyedProperty></KeyedObject>',
'  <KeyedObject objectId="0:230"><KeyedProperty propertyKey="16"><KeyFrameDouble value="1" frame="0"/><KeyFrameDouble value="1" frame="47"/><KeyFrameDouble value="0.06" frame="52" interpolationType="cubic"/><KeyFrameDouble value="1.12" frame="56" interpolationType="cubic"/><KeyFrameDouble value="1" frame="61"/></KeyedProperty><KeyedProperty propertyKey="17"><KeyFrameDouble value="1" frame="0"/><KeyFrameDouble value="1.08" frame="56"/><KeyFrameDouble value="1" frame="61"/></KeyedProperty></KeyedObject>',
'  <KeyedObject objectId="0:231"><KeyedProperty propertyKey="37"><KeyFrameColor value="FF0F1B2E" frame="0"/><KeyFrameColor value="FF0F1B2E" frame="50"/><KeyFrameColor value="FF22C8FF" frame="56"/><KeyFrameColor value="FF22C8FF" frame="105"/></KeyedProperty></KeyedObject>',
'  <KeyedObject objectId="0:240"><KeyedProperty propertyKey="16"><KeyFrameDouble value="1" frame="0"/><KeyFrameDouble value="1" frame="73"/><KeyFrameDouble value="0.06" frame="78" interpolationType="cubic"/><KeyFrameDouble value="1.12" frame="82" interpolationType="cubic"/><KeyFrameDouble value="1" frame="87"/></KeyedProperty><KeyedProperty propertyKey="17"><KeyFrameDouble value="1" frame="0"/><KeyFrameDouble value="1.08" frame="82"/><KeyFrameDouble value="1" frame="87"/></KeyedProperty></KeyedObject>',
'  <KeyedObject objectId="0:241"><KeyedProperty propertyKey="37"><KeyFrameColor value="FF0F1B2E" frame="0"/><KeyFrameColor value="FF0F1B2E" frame="76"/><KeyFrameColor value="FF22C8FF" frame="82"/><KeyFrameColor value="FF22C8FF" frame="105"/></KeyedProperty></KeyedObject>',
'</LinearAnimation>'
].join('\n');
s=s.replace(/<LinearAnimation duration="(?:42|90|105)" name="TraceAndConnect" id="0:52">[\s\S]*?<\/LinearAnimation>/, trace);
const arrival = [
'<LinearAnimation duration="18" name="Arrival" id="0:53">',
'  <KeyedObject objectId="0:211"><KeyedProperty propertyKey="115"><KeyFrameDouble value="1" frame="0"/></KeyedProperty></KeyedObject>',
'  <KeyedObject objectId="0:250"><KeyedProperty propertyKey="16"><KeyFrameDouble value="1" frame="0"/><KeyFrameDouble value="1.12" frame="8" interpolationType="cubic"/><KeyFrameDouble value="1" frame="18"/></KeyedProperty><KeyedProperty propertyKey="17"><KeyFrameDouble value="1" frame="0"/><KeyFrameDouble value="1.12" frame="8" interpolationType="cubic"/><KeyFrameDouble value="1" frame="18"/></KeyedProperty></KeyedObject>',
'</LinearAnimation>'
].join('\n');
s=s.replace(/<LinearAnimation duration="(?:12|18)" name="Arrival" id="0:53">[\s\S]*?<\/LinearAnimation>/, arrival);
const wordmark = [
'<LinearAnimation duration="24" name="Wordmark" id="0:54">',
'  <KeyedObject objectId="0:211"><KeyedProperty propertyKey="115"><KeyFrameDouble value="1" frame="0"/></KeyedProperty></KeyedObject>',
'  <KeyedObject objectId="0:300"><KeyedProperty propertyKey="18"><KeyFrameDouble value="1" frame="0"/></KeyedProperty></KeyedObject>',
'  <KeyedObject objectId="0:301"><KeyedProperty propertyKey="18"><KeyFrameDouble value="0" frame="0"/><KeyFrameDouble value="1" frame="15" interpolationType="cubic"/></KeyedProperty></KeyedObject>',
'  <KeyedObject objectId="0:310"><KeyedProperty propertyKey="18"><KeyFrameDouble value="0" frame="0"/><KeyFrameDouble value="0" frame="15"/><KeyFrameDouble value="1" frame="24" interpolationType="cubic"/></KeyedProperty></KeyedObject>',
'</LinearAnimation>'
].join('\n');
s=s.replace(/<LinearAnimation duration="(?:12|24)" name="Wordmark" id="0:54">[\s\S]*?<\/LinearAnimation>/, wordmark);
s=s.replace('name="BrandTitle" id="0:301"', 'name="BrandTitle" id="0:301" opacity="0"');
s=s.replace('name="Tagline" id="0:310"', 'name="Tagline" id="0:310" opacity="0"');
s=s.replace(/(?: opacity="0")+/g, ' opacity="0"');
const nodeMarker='<!-- 4. Speed Trail Lines (Mobility) -->';
const sceneParts=s.split(nodeMarker);
if(sceneParts.length>1) {
  sceneParts[1]=sceneParts[1].replaceAll('name="PinBlue" id="0:253"', 'name="Cerulean"');
  s=sceneParts.join(nodeMarker);
}
if(!s.includes('start="0" end="0" name="Trim"')) {
  s=s.replace('start="0" end="1" name="Trim"', 'start="0" end="0" name="Trim"');
}
if(!s.includes('name="RouteLight"')) {
  s=s.replace('<Stroke thickness="8" cap="round" join="round">\n                <SolidColor colorValue="FF0A66C2" name="CeruleanBlue"/>', '<Stroke thickness="5" cap="round" join="round">\n                <SolidColor colorValue="FF22C8FF" name="RouteLight"/>');
}
const staticState = /(<LinearAnimation duration="1" name="Static" id="0:51">[\s\S]*?<\/LinearAnimation>)/;
s=s.replace(staticState, block => block.replace('<KeyFrameDouble value="1" frame="0" interpolationType="linear"/>', '<KeyFrameDouble value="0" frame="0" interpolationType="linear"/>'));
if(!s.includes('name="PinBlue" id="0:253"')) {
  s=s.replace(/(<Shape[^>]*name="PinBody"[^>]*>[\s\S]*?<\/PointsPath>\s*<Fill name="Fill"><SolidColor )colorValue="FF0A66C2" name="Cerulean"/, '$1colorValue="FF0A66C2" name="PinBlue" id="0:253"');
}
const pinColor = '  <KeyedObject objectId="0:253"><KeyedProperty propertyKey="37"><KeyFrameColor value="FF0A66C2" frame="0"/><KeyFrameColor value="FF22C8FF" frame="5" interpolationType="cubic"/></KeyedProperty></KeyedObject>';
s=s.replace('<KeyedObject objectId="0:250"><KeyedProperty propertyKey="16">', pinColor+'\n  <KeyedObject objectId="0:250"><KeyedProperty propertyKey="16">');
s=s.replace(/(<LinearAnimation duration="105" name="TraceAndConnect" id="0:52">[\s\S]*?<\/LinearAnimation>)/, block => block.replace(/<KeyFrameDouble (?![^>]*interpolationType)([^>]*)\/>/g, '<KeyFrameDouble $1 interpolationType="cubic"/>').replace(/<KeyFrameColor (?![^>]*interpolationType)([^>]*)\/>/g, '<KeyFrameColor $1 interpolationType="linear"/>'));
s=s.replace(/(<LinearAnimation duration="18" name="Arrival" id="0:53">[\s\S]*?<\/LinearAnimation>)/, block => block.replace(/<KeyFrameDouble (?![^>]*interpolationType)([^>]*)\/>/g, '<KeyFrameDouble $1 interpolationType="cubic"/>').replace(/<KeyFrameColor (?![^>]*interpolationType)([^>]*)\/>/g, '<KeyFrameColor $1 interpolationType="linear"/>'));
if (!s.includes('name="Node1Navy"') || !s.includes('KeyFrameColor value="FF22C8FF" frame="105"')) throw new Error('Rive node ids or animation sequence missing');
fs.writeFileSync(file, s);
const darkFile=path.join(__dirname,'..','rive_splash_dark','scene.rml');
let d=s;
d=d.replaceAll('colorValue="FFFFFFFF" name="WhiteBg"', 'colorValue="FF0A1424" name="NavyBg"');
d=d.replaceAll('colorValue="FFFFFFFF" name="White"', 'colorValue="FF0A1424" name="NavyCutout"');
d=d.replaceAll('colorValue="FF0F1B2E" name="NavyColor"', 'colorValue="FF1C3454" name="NavyColor"');
d=d.replaceAll('colorValue="FF0F1B2E" name="Navy"', 'colorValue="FFEAF3FF" name="Navy"');
d=d.replaceAll('colorValue="FF0F1B2E" name="NavyText"', 'colorValue="FFAFC2DA" name="NavyText"');
d=d.replaceAll('colorValue="FF0F1B2E" name="Node1Navy"', 'colorValue="FF496584" name="Node1Navy"');
d=d.replaceAll('colorValue="FF0F1B2E" name="Node2Navy"', 'colorValue="FF496584" name="Node2Navy"');
d=d.replaceAll('colorValue="FF0F1B2E" name="Node3Navy"', 'colorValue="FF496584" name="Node3Navy"');
fs.writeFileSync(darkFile,d);
