// Optional private live-asset verification. No screenshots or media exported.
const {chromium}=require('playwright');
const fs=require('node:fs/promises'),path=require('node:path'),{pathToFileURL}=require('node:url'),assert=require('node:assert/strict'),crypto=require('node:crypto');
(async()=>{
  const directory=path.resolve(process.argv[2]);
  const files=(await fs.readdir(directory)).filter(f=>f.endsWith('.avif')).sort();
  assert(files.length>0,'No live AVIF assets supplied');
  const browser=await chromium.launch({headless:true});
  try{
    const context=await browser.newContext();await context.setOffline(true);
    const page=await context.newPage();
    await page.goto(pathToFileURL(path.resolve(__dirname,'../reader.html')).href);
    const result=[];
    for(const file of files){
      await page.locator('#files').setInputFiles(path.join(directory,file));
      await page.waitForFunction(()=>{const e=document.querySelector('#pages img');return e&&e.complete&&e.naturalWidth>0;},null,{timeout:30000});
      const img=page.locator('#pages img');
      const data=await img.evaluate(e=>({width:e.naturalWidth,height:e.naturalHeight}));
      // Canvas drawImage uses an animation's default frame. Sample the actual
      // compositor output instead, hash it in memory, and never save the image.
      const hashes=new Set();
      for(let j=0;j<8;j++){
        hashes.add(crypto.createHash('sha256').update(await img.screenshot()).digest('hex'));
        await page.waitForTimeout(170);
      }
      data.distinctRenderedFrames=hashes.size;
      assert(data.distinctRenderedFrames>1,'Live AVIF did not animate: '+file);
      result.push({file,...data});console.log('PASS: real offline AVIF '+file+' rendered '+data.distinctRenderedFrames+' distinct sampled frames');
    }
    await fs.writeFile(process.argv[3]||'live-reader-results.json',JSON.stringify({browser:browser.version(),networkDisabled:true,files:result},null,2));
  } finally{await browser.close();}
})().catch(e=>{console.error(e);process.exitCode=1;});
