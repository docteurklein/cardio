var Main = require('./output/Main');

if (module.hot) {
  module.hot.accept(function () {
    console.log('Reloaded, running main again');
    Main.main(process.env.BASE_URL);
  });
}

console.log('Starting app');

Main.main(process.env.BASE_URL);
