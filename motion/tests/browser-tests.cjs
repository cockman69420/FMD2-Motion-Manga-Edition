// Offline browser integration tests. npm install playwright; npx playwright install chromium
const {chromium} = require('playwright');
const fs=require('node:fs/promises'), path=require('node:path'), {pathToFileURL}=require('node:url'), crypto=require('node:crypto'), assert=require('node:assert/strict');
const root=path.resolve(__dirname,'../..'), fixtures=path.join(__dirname,'fixtures');
const output=path.resolve(process.env.MOTION_TEST_OUTPUT||path.join(root,'.motion-build/browser-results'));
let browser;
const checks=[];
function pass(name){checks.push(name);console.log('PASS: '+name);}
async function waitLoaded(page,n){await page.waitForFunction(n=>document.querySelectorAll('#pages img,#pages video').length===n && [...document.querySelectorAll('#pages img,#pages video')].every(e=>e.tagName==='IMG'?e.complete&&e.naturalWidth>0:e.readyState>=2),n,{timeout:20000});}
async function animationCheck(page,locator,name){
  const hashes=new Set();
  for(let i=0;i<8;i++){hashes.add(crypto.createHash('sha256').update(await locator.screenshot()).digest('hex'));await page.waitForTimeout(110);}
  assert(hashes.size>=2, name+' must actually animate');pass(name+' rendered multiple distinct frames');
}
(async()=>{
  await fs.mkdir(output,{recursive:true});
  browser=await chromium.launch({headless:true});
  const context=await browser.newContext({viewport:{width:1280,height:900}});
  await context.setOffline(true);
  const page=await context.newPage();
  let network=0; const errors=[];
  page.on('request',r=>{if(/^https?:/.test(r.url()))network++;});
  page.on('pageerror',e=>errors.push(e.message));
  await page.goto(pathToFileURL(path.join(root,'motion/reader.html')).href);
  await page.screenshot({path:path.join(output,'reader-welcome.png'),fullPage:true});
  pass('reader opens with browser network disabled');
  await page.locator('#files').setInputFiles(path.join(fixtures,'demo-motion.cbz'));
  await waitLoaded(page,7);
  assert.equal(await page.locator('#pages img').count(),5);
  assert.equal(await page.locator('#pages video').count(),2);
  assert.equal(await page.locator('#pages img').nth(1).evaluate(e=>e.naturalWidth),640);
  pass('original resolution; stored CBZ mixed images, AVIF, MP4 and WebM');
  for(const [index,name] of [[1,'AVIF'],[2,'WebP'],[3,'GIF'],[4,'APNG']]) await animationCheck(page,page.locator('#pages img').nth(index),name);
  for(const [index,name] of [[0,'MP4'],[1,'WebM']]){
    const el=page.locator('#pages video').nth(index);await el.scrollIntoViewIfNeeded();await el.evaluate(e=>e.play());
    await animationCheck(page,el,name);
  }
  await page.locator('#pause').click();assert(await page.locator('#pages video').evaluateAll(es=>es.every(e=>e.paused)));pass('video pause control');
  await page.locator('#restart').click();pass('animation restart control');
  await page.screenshot({path:path.join(output,'reader-chapter.png'),fullPage:true});
  await page.locator('#files').setInputFiles(path.join(fixtures,'demo-deflate.cbz'));await waitLoaded(page,7);pass('DEFLATE CBZ decoded and checksums validated offline');
  await page.locator('#files').setInputFiles(path.join(fixtures,'corrupt-crc.cbz'));await page.waitForFunction(()=>document.querySelector('#status').textContent.includes('afspilningsfejl'));pass('corrupt member CRC rejected visibly');
  await page.locator('#files').setInputFiles(path.join(fixtures,'not-a-zip.cbz'));await page.waitForFunction(()=>document.querySelector('#status').textContent.includes('ikke et understøttet'));pass('invalid archive rejected visibly');
  const library=path.join(output,'library');
  for(const chapter of ['Kapitel 2','Kapitel 10']){await fs.mkdir(path.join(library,chapter),{recursive:true});await fs.copyFile(path.join(fixtures,'animated.avif'),path.join(library,chapter,'001.avif'));}
  await page.locator('#folder').setInputFiles(library);await waitLoaded(page,1);
  assert.equal(await page.locator('#chapter option').count(),2);assert((await page.locator('#chapter option').first().textContent()).includes('Kapitel 2'));pass('folder library and natural chapter order');
  await page.locator('#chapter').selectOption('1');await waitLoaded(page,1);pass('chapter switching');
  await page.setViewportSize({width:390,height:844});await page.locator('#reset').click();await page.screenshot({path:path.join(output,'reader-mobile.png'),fullPage:true});
  assert(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth));pass('narrow layout');
  assert.equal(network,0);assert.deepEqual(errors,[]);pass('zero network requests and no JavaScript errors');
  await fs.writeFile(path.join(output,'browser-results.json'),JSON.stringify({browser:browser.version(),passed:checks.length,checks,networkRequests:network,errors},null,2));
  await browser.close();console.log('RESULT: '+checks.length+' checks passed');
})().catch(async e=>{console.error(e);if(browser)await browser.close();process.exitCode=1;});
