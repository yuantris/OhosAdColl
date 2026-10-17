import { harTasks } from '@ohos/hvigor-ohos-plugin';
import fs from 'fs'

export function renameHarTask(str?: string) {
    return {
        pluginId: 'RenameHarTaskID',
        apply(pluginContext) {
            pluginContext.registerTask({
                name: 'renameHarTask',
                run: (taskContext) => {
                    const packageFile = taskContext.modulePath + '\\oh-package.json5';
                    console.log('file: ', packageFile);

                    let fileContent = fs.readFileSync(packageFile, 'utf8');

                    // 使用正则表达式提取JSON5中的字段值
                    function extractJson5Value(content: string, key: string): string | null {
                        // 匹配 "key": "value" 格式
                        const regex = new RegExp(`"${key}"\\s*:\\s*"([^"]+)"`, 'g');
                        const match = regex.exec(content);
                        return match ? match[1] : null;
                    }

                    // 提取version和author
                    const version = extractJson5Value(fileContent, 'version') || 'unknown';
                    const author = extractJson5Value(fileContent, 'author') || 'unknown';

                    const sourceFile = taskContext.modulePath + '\\build\\default\\outputs\\default\\' + taskContext.moduleName + '.har';
                    const targetPath = taskContext.modulePath + '\\build\\default\\outputs\\target\\';
                    const targetFile = targetPath + taskContext.moduleName + '-' + version + '.har';

                    // 确保源文件存在
                    if (!fs.existsSync(sourceFile)) {
                        console.error('源文件不存在: ', sourceFile);
                        return;
                    }

                    // 创建目标目录
                    fs.mkdirSync(targetPath, { recursive: true });

                    // 移动并重命名文件
                    try {
                        fs.renameSync(sourceFile, targetFile);
                        console.log('文件重命名成功: ', targetFile);
                    } catch (err) {
                        console.error('文件重命名失败: ', err);
                    }
                },
                dependencies: ['default@PackageHar'],
                postDependencies: ['assembleHar']
            })
        }
    }
}

export default {
    system: harTasks,
    plugins: [renameHarTask()]
}