local function read(path) local f=assert(io.open(path,'rb'));local s=f:read('*a');f:close();return s end
local m=require 'motion.MangaDistrict'
local values={}
local links={Count=0}
links.Clear=function() values={};links.Count=0 end
links.Add=function(s) values[#values+1]=s;links.Count=#values end
assert(m.Extract(CreateTXQuery(read(FIXTURES..'parser.html')), 'https://example.test/chapter/1/',links))
assert(#values==5,'expected five visual pages, no noscript duplicate or advertisement')
assert(values[1]=='https://example.test/one.jpg')
assert(values[2]=='https://cdn.example/two.avif')
assert(values[3]=='https://example.test/chapter/1/three.avif',values[3])
assert(values[4]=='https://cdn.example/four.webm')
assert(values[5]=='https://example.test/chapter/1/five.gif')
assert(not m.Extract(CreateTXQuery('<div>no pages</div>'),'https://example.test/',links))
assert(not m.Extract(CreateTXQuery('<div class="page-break"><img src="data:image/gif,x"></div>'),'https://example.test/',links))
assert(not m.Extract(CreateTXQuery('<div class="page-break"><video src="test.m3u8"></video></div>'),'https://example.test/',links))
assert(not m.Extract(CreateTXQuery('<div class="page-break"><img src="first.jpg"></div><div class="page-break"><img src="data:image/gif,x"></div>'),'https://example.test/',links))
assert(links.Count==0,'a partial chapter must not be reported as success')
