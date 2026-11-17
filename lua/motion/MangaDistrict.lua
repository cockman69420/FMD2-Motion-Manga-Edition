-- FMD2 Motion Manga Edition, GPL-2.0-or-later.
local M = {}

local function clean(s)
    s = (s or ''):match('^%s*(.-)%s*$')
    if s == '' or s:match('^data:') or s:match('^blob:') then return '' end
    return s
end

local function largest(srcset)
    local best, score = '', -1
    for url, descriptor in (srcset .. ','):gmatch('%s*([^%s,]+)%s*([^,]*),') do
        local n = tonumber(descriptor:match('([%d%.]+)')) or 1
        if n > score then best, score = clean(url), n end
    end
    return best
end

local function absolute(base, path)
    if path:match('^https?://') then return path end
    if path:sub(1, 2) == '//' then return 'https:' .. path end
    local root = base:match('^(https?://[^/]+)')
    if not root then return '' end
    if path:sub(1, 1) == '/' then return root .. path end
    base = base:gsub('[?#].*$', ''):match('^(.*)/') .. '/'
    local result = base .. path
    while result:find('/[^/]+/%.%./') do result = result:gsub('/[^/]+/%.%./', '/') end
    return result:gsub('/%./', '/')
end

function M.Extract(x, base, links)
    links.Clear()
    local function fail() links.Clear(); return false end
    -- One resource per visual element, in document order; no noscript duplicates.
    local selector = '//div[contains(concat(" ", normalize-space(@class), " "), " page-break ")]' ..
        '//*[self::img or self::picture or self::video]' ..
        '[not(ancestor::noscript) and not(ancestor::picture) and not(ancestor::video)]'
    for node in x.XPath(selector).Get() do
        local url = ''
        local kind = x.XPathString('name(.)', node):lower()
        if kind == 'picture' then
            local set = x.XPathString('(.//source/@data-srcset, .//source/@srcset)[1]', node)
            url = largest(set)
            if url == '' then
                url = clean(x.XPathString('(.//img/@data-original, .//img/@data-src, .//img/@data-lazy-src, .//img/@src)[normalize-space(.)!="" and not(starts-with(normalize-space(.),"data:"))][1]', node))
            end
        elseif kind == 'video' then
            url = clean(x.XPathString('(@data-src, @src, .//source/@data-src, .//source/@src)[normalize-space(.)!=""][1]', node))
        else
            for _, attribute in ipairs({'data-original', 'data-src', 'data-lazy-src', 'src'}) do
                url = clean(x.XPathString('@' .. attribute, node))
                if url ~= '' then break end
            end
            if url == '' then url = largest(x.XPathString('(@data-srcset, @srcset)[1]', node)) end
        end
        if url == '' then return fail() end -- Never report an incomplete chapter as complete.
        url = absolute(base, url)
        if not url:match('^https?://') then return fail() end
        if url:lower():match('%.m3u8[?]?') or url:lower():match('%.mpd[?]?') then return fail() end
        links.Add(url)
    end
    return links.Count > 0
end

function M.GetPageNumber()
    local u = MaybeFillHost(MODULE.RootURL, URL)
    if not u:find('style=list', 1, true) then
        u = u:gsub('style=paged', 'style=list')
        if not u:find('style=list', 1, true) then
            u = u .. (u:find('?', 1, true) and '&' or '?') .. 'style=list'
        end
    end
    if not HTTP.GET(u) then return false end
    return M.Extract(CreateTXQuery(HTTP.Document), u, TASK.PageLinks)
end

function M.BeforeDownloadImage()
    HTTP.Headers.Values['Referer'] = MODULE.RootURL .. '/'
    HTTP.Headers.Values['Accept'] = 'image/avif,image/webp,image/apng,image/*,video/webm,video/mp4,*/*;q=0.8'
    return true
end

return M
