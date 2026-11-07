const { getDefaultConfig } = require('expo/metro-config');
const path = require('path');

const config = getDefaultConfig(__dirname);

// Diz ao Metro para usar o nosso ficheiro mock apenas quando estiver na Web
config.resolver.resolveRequest = (context, moduleName, platform) => {
  if (platform === 'web' && moduleName === 'react-native-maps') {
    return {
      filePath: path.resolve(__dirname, 'react-native-maps-mock.js'),
      type: 'sourceFile',
    };
  }
  
  // Para tudo o resto (ou se estiveres a correr no Android/iOS), usa o comportamento normal
  return context.resolveRequest(context, moduleName, platform);
};

module.exports = config;