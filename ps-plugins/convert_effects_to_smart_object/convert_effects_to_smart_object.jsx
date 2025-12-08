// Photoshop 脚本：将所有有特效的末端元素转换为智能对象
// 循环处理直到没有任何末端元素有特效
// 使用方法：文件 > 脚本 > 浏览，然后选择此脚本

#target photoshop

// 确保有打开的文档
if (app.documents.length === 0) {
    alert("请先打开一个 PSD 文档");
} else {
    main();
}

function main() {
    var doc = app.activeDocument;
    var totalConverted = 0;
    var iteration = 0;
    var continueProcessing = true;

    try {
        // 循环处理，直到没有任何末端元素有特效
        while (continueProcessing) {
            iteration++;
            var stats = {
                converted: 0,
                processed: 0,
                skipped: 0,
                alreadySmartObject: 0
            };

            $.writeln("===== 第 " + iteration + " 轮处理 =====");

            // 处理所有图层
            processLayers(doc, stats);

            totalConverted += stats.converted;

            $.writeln("本轮处理：" + stats.processed + " 个末端元素");
            $.writeln("本轮跳过：" + stats.skipped + " 个");
            $.writeln("本轮转换：" + stats.converted + " 个");

            // 如果本轮没有转换任何图层，说明处理完成
            if (stats.converted === 0) {
                continueProcessing = false;
            }

            // 安全限制：最多处理20轮
            if (iteration >= 20) {
                alert("已达到最大处理轮数(20轮)，停止处理。");
                break;
            }
        }

        var message = "处理完成！\n\n" +
                      "共进行：" + iteration + " 轮处理\n" +
                      "总共转换：" + totalConverted + " 个元素";

        alert(message);
    } catch (e) {
        alert("错误：" + e.message + "\n行号：" + e.line);
    }
}

function processLayers(parent, stats) {
    try {
        // 从后向前遍历图层（避免索引变化问题）
        for (var i = parent.layers.length - 1; i >= 0; i--) {
            try {
                var layer = parent.layers[i];

                // 跳过不可访问的图层
                if (!canAccessLayer(layer)) {
                    stats.skipped++;
                    continue;
                }

                // 如果是图层组
                if (layer.typename === "LayerSet") {
                    // 检查这个组是否是末端组（没有子图层组）
                    if (isEndGroup(layer)) {
                        stats.processed++;

                        // 检查是否已经是智能对象
                        if (isSmartObject(layer)) {
                            stats.alreadySmartObject++;
                            continue;
                        }

                        // 检查是否有特效
                        if (hasLayerEffects(layer)) {
                            try {
                                // 选中该图层组
                                app.activeDocument.activeLayer = layer;

                                // 转换为智能对象
                                convertToSmartObject();

                                stats.converted++;
                                $.writeln("转换图层组：" + layer.name);
                            } catch (e) {
                                $.writeln("无法转换图层组 '" + layer.name + "': " + e.message);
                                stats.skipped++;
                            }
                        }
                    } else {
                        // 如果不是末端组，递归处理其子图层
                        processLayers(layer, stats);
                    }
                }
                // 如果是普通图层（不管是什么类型）
                else if (layer.typename === "ArtLayer") {
                    stats.processed++;

                    // 检查是否已经是智能对象
                    if (isSmartObject(layer)) {
                        stats.alreadySmartObject++;
                        continue;
                    }

                    // 检查是否有特效
                    if (hasLayerEffects(layer)) {
                        try {
                            // 选中该图层
                            app.activeDocument.activeLayer = layer;

                            // 转换为智能对象
                            convertToSmartObject();

                            stats.converted++;
                            $.writeln("转换图层：" + layer.name);
                        } catch (e) {
                            $.writeln("无法转换图层 '" + layer.name + "': " + e.message);
                            stats.skipped++;
                        }
                    }
                }
            } catch (e) {
                $.writeln("处理图层时出错: " + e.message);
                stats.skipped++;
                continue;
            }
        }
    } catch (e) {
        $.writeln("遍历图层时出错: " + e.message);
    }
}

// 检查图层是否可以访问
function canAccessLayer(layer) {
    try {
        // 尝试访问基本属性
        var name = layer.name;
        var type = layer.typename;

        // 检查是否是背景图层
        if (layer.typename === "ArtLayer" && layer.isBackgroundLayer) {
            return false;
        }

        // 检查是否锁定
        if (layer.allLocked) {
            return false;
        }

        return true;
    } catch (e) {
        return false;
    }
}

// 检查图层组是否是末端组（不包含子图层组）
function isEndGroup(layerSet) {
    try {
        for (var i = 0; i < layerSet.layers.length; i++) {
            if (layerSet.layers[i].typename === "LayerSet") {
                return false;
            }
        }
        return true;
    } catch (e) {
        return false;
    }
}

// 检查图层是否已经是智能对象
function isSmartObject(layer) {
    try {
        var ref = new ActionReference();
        ref.putIdentifier(charIDToTypeID("Lyr "), layer.id);
        var desc = executeActionGet(ref);

        if (desc.hasKey(stringIDToTypeID("smartObject"))) {
            return true;
        }

        // 另一种检测方法
        if (layer.kind == LayerKind.SMARTOBJECT) {
            return true;
        }

        return false;
    } catch (e) {
        return false;
    }
}

// 检查图层是否有特效
function hasLayerEffects(layer) {
    try {
        var ref = new ActionReference();
        ref.putIdentifier(charIDToTypeID("Lyr "), layer.id);
        var desc = executeActionGet(ref);

        // 检查是否有 layerEffects 键
        if (!desc.hasKey(stringIDToTypeID("layerEffects"))) {
            return false;
        }

        var effectsDesc = desc.getObjectValue(stringIDToTypeID("layerEffects"));

        // 检查特效描述符是否有任何内容
        if (effectsDesc.count > 0) {
            return true;
        }

        return false;
    } catch (e) {
        // 如果获取失败，返回false
        return false;
    }
}

// 转换当前图层为智能对象
function convertToSmartObject() {
    var idnewPlacedLayer = stringIDToTypeID("newPlacedLayer");
    executeAction(idnewPlacedLayer, undefined, DialogModes.NO);
}
