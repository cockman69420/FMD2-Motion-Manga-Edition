-- FMD2 Motion Manga Edition. Original module ID retained for existing favourites.
local Template = require 'templates.Madara'
local Motion = require 'motion.MangaDistrict'
function GetNameAndLink() return Template.GetNameAndLink() end
function GetInfo() return Template.GetInfo() end
function GetPageNumber() return Motion.GetPageNumber() end
function BeforeDownloadImage() return Motion.BeforeDownloadImage() end
function SaveImage() return require('fmd.motion').SaveOriginal(HTTP.Document, PATH, FILENAME) end
function Init()
    local m = NewWebsiteModule()
    m.ID = '6d66888d64ef45e0a97d1912bda87282'
    m.Name = 'Manga District'
    m.RootURL = 'https://mangadistrict.com'
    m.Category = 'H-Sites'
    m.OnGetNameAndLink = 'GetNameAndLink'
    m.OnGetInfo = 'GetInfo'
    m.OnGetPageNumber = 'GetPageNumber'
    m.OnBeforeDownloadImage = 'BeforeDownloadImage'
    m.OnSaveImage = 'SaveImage'
end
