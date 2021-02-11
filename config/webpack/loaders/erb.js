module.exports = {
  test: /\.erb$/,
  enforce: 'pre',
  exclude: /node_modules/,
  use: [{
    loader: 'rails-erb-loader',
    options: {
      runner: 'bundle exec bin/rails runner'
      // Note: below was the original for the above line that resulted from
      // installed this package using: bundle exec rails webpacker:install:erb
      // Not using `bundle exec` causes Webpacker to timeout when trying to compile.
      //runner: (/^win/.test(process.platform) ? 'ruby ' : '') + 'bin/rails runner'
    }
  }]
}
