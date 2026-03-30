{{flutter_js}}
{{flutter_build_config}}

_flutter.loader.load({
  onEntrypointLoaded: async function(engineInitializer) {
    const appRunner = await engineInitializer.initializeEngine();
    
    // Remove the custom loading indicator once Flutter engine is ready
    const loader = document.getElementById('global-coolers-loader');
    if (loader) {
      loader.remove();
    }
    
    await appRunner.runApp();
  }
});
