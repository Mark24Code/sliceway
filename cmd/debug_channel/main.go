package main

import (
	"fmt"
	"log"
	"psd2img/source/psd"
)

func main() {
	doc, err := psd.Open("./uploads/1765525860_baibaibai-透明背景.psd")
	if err != nil {
		log.Fatal(err)
	}
	defer doc.Close()

	// 查找 "颜色填充 2" 图层
	var targetLayer *psd.Layer
	for _, layer := range doc.Layers {
		if layer.Name == "颜色填充 2" {
			targetLayer = layer
			break
		}
	}

	if targetLayer == nil {
		log.Fatal("Layer not found")
	}

	fmt.Printf("Found layer: %s\n", targetLayer.Name)
	fmt.Printf("Opacity: %d\n", targetLayer.Opacity)
	fmt.Printf("Channels: %d\n", targetLayer.Channels)
	fmt.Printf("Channel Info:\n")
	for _, ch := range targetLayer.ChannelInfo {
		fmt.Printf("  Channel ID=%d, Length=%d\n", ch.ID, ch.Length)
	}

	// 获取通道数据
	fmt.Printf("\nChannel Data:\n")
	for id, data := range targetLayer.ChannelData {
		fmt.Printf("  Channel %d: %d bytes\n", id, len(data))
		if len(data) > 0 {
			// 打印前10个字节
			end := 10
			if len(data) < end {
				end = len(data)
			}
			fmt.Printf("    First %d bytes: %v\n", end, data[:end])

			// 检查是否所有字节都相同
			allSame := true
			if len(data) > 1 {
				first := data[0]
				for _, b := range data[1:] {
					if b != first {
						allSame = false
						break
					}
				}
				if allSame {
					fmt.Printf("    All bytes are the same: %d\n", first)
				}
			}
		}
	}
}
