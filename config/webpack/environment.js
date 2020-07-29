const { environment } = require('@rails/webpacker')
const webpack = require('webpack')
const ckeditorSVG = require('./loaders/ckeditor-svg')
const ckeditorCSS = require('./loaders/ckeditor-css')
const CKEditorWebpackPlugin = require( '@ckeditor/ckeditor5-dev-webpack-plugin' )

environment.loaders.append('ckeditorCSS', ckeditorCSS)
environment.loaders.append('ckeditorSVG', ckeditorSVG)

const cssLoader = environment.loaders.get('css');
cssLoader.exclude = /(\.module\.[a-z]+$)|(ckeditor5-[^/\\]+[/\\]theme[/\\].+\.css)/

const fileLoader = environment.loaders.get('file');
fileLoader.exclude = /ckeditor5-[^/\\]+[/\\]theme[/\\]icons[/\\][^/\\]+\.svg$/

environment.plugins.append("Provide", new webpack.ProvidePlugin({
  $: 'jquery',
  jQuery: 'jquery',
  Popper: ['popper.js', 'default']
}))

module.exports = environment
