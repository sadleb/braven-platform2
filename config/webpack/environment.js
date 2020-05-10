const { environment } = require('@rails/webpacker')
const dotenv = require('dotenv')
const ckeditorSVG = require('./loaders/ckeditor-svg')
const ckeditorCSS = require('./loaders/ckeditor-css')
const CKEditorWebpackPlugin = require( '@ckeditor/ckeditor5-dev-webpack-plugin' )

const dotenvFiles = [
  `.env.${process.env.NODE_ENV}.local`,
  '.env.local',
  `.env.${process.env.NODE_ENV}`,
  '.env',
]
dotenvFiles.forEach((dotenvFile) => {
  dotenv.config({ path: dotenvFile, silent: true })
})

environment.plugins.prepend('CKEditor', new CKEditorWebpackPlugin({
        language: 'en'
    })
)

environment.loaders.append('ckeditorCSS', ckeditorCSS)
environment.loaders.append('ckeditorSVG', ckeditorSVG)

const cssLoader = environment.loaders.get('css');
cssLoader.exclude = /(\.module\.[a-z]+$)|(ckeditor5-[^/\\]+[/\\]theme[/\\].+\.css)/

const fileLoader = environment.loaders.get('file');
fileLoader.exclude = /ckeditor5-[^/\\]+[/\\]theme[/\\]icons[/\\][^/\\]+\.svg$/

module.exports = environment
