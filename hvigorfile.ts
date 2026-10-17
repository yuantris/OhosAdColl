import { appTasks, OhosAppContext, OhosPluginId } from '@ohos/hvigor-ohos-plugin';
import { FileUtil, hvigor } from '@ohos/hvigor'
import fs from 'fs'

/**
 * 添加自定义插件，修改工程级oh-package.json5文件中的dependency依赖
 */
export function addDependenciesPlugin(): HvigorPlugin {
  return {
    pluginId: 'addDependenciesPlugin',
    async apply(currentNode: HvigorNode): Promise<void> {
      const appContext = currentNode.getContext(OhosPluginId.OHOS_APP_PLUGIN) as OhosAppContext;
      const dependency = appContext.getDependenciesOpt(); //获取dependency依赖
      const buildProfileOpt = appContext.getBuildProfileOpt();

      const projectPath = appContext.getProjectPath()
      console.log(`projectPath: ${projectPath}`);
      const json5 = FileUtil.pathResolve('./entry', 'build-profile.json5')
      // FileUtil.ensureFileSync(json5)
      let fileContent = fs.readFileSync(json5, 'utf8');
      // console.log(fileContent);

      // dependency["library"]="file:library.har"
      console.log(dependency);

      const allNodes = hvigor.getAllNodes();
      // console.log(JSON.stringify(allNodes));
      // console.log(JSON.stringify(buildProfileOpt));
      // appContext.setDependenciesOpt(dependency );  //修改dependency依赖
    }
  };
}

/**
 * 添加自定义插件，修改工程级oh-package.json5文件中的dependency依赖
 */
export function infoJsonPlugin(): HvigorPlugin {
  return {
    pluginId: 'infoJsonPlugin',
    async apply(currentNode: HvigorNode): Promise<void> {
      const appContext = currentNode.getContext(OhosPluginId.OHOS_APP_PLUGIN) as OhosAppContext;
      const dependency = appContext.getDependenciesOpt(); //获取dependency依赖

      const projectPath = appContext.getProjectPath()
      console.log(`projectPath: ${projectPath}`);
      const infoJson = FileUtil.pathResolve('./entry/src/main/resources/rawfile', 'info.json')
      // FileUtil.ensureFileSync(json5)
      const info = FileUtil.readJson5(infoJson)
      // let fileContent = fs.readFileSync(json5, 'utf8');
      // console.log(info);

      // dependency["library"]="file:library.har"
      // console.log(dependency);
      // appContext.setDependenciesOpt(dependency );  //修改dependency依赖
    }
  };
}

export default {
  system: appTasks, /* Built-in plugin of Hvigor. It cannot be modified. */
  plugins: [addDependenciesPlugin(),
    infoJsonPlugin()]         /* Custom plugin to extend the functionality of Hvigor. */
}
