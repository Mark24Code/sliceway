import type { Layer } from '../types';

export class CodeGenerator {
    static generateCSS(layer: Layer): string {
        if (layer.layer_type === 'text') {
            return `/* Text Style */
font-family: '${layer.metadata?.font?.name || 'inherit'}';
font-size: ${layer.metadata?.font?.sizes?.[0] || 'inherit'}px;
color: ${layer.metadata?.font?.colors?.[0] ? `rgb(${layer.metadata.font.colors[0].join(',')})` : 'inherit'};
line-height: 1.5;`;
        } else {
            return `/* Image Style */
width: ${layer.width}px;
height: ${layer.height}px;
background-image: url('${layer.name}.png');
background-size: cover;`;
        }
    }

    static generateSCSS(layer: Layer): string {
        // SCSS is similar to CSS for basic properties, but we can add nesting or variables if needed in future
        return this.generateCSS(layer);
    }

    static generateLess(layer: Layer): string {
        // Less is similar to CSS for basic properties
        return this.generateCSS(layer);
    }

    static generateVue(layer: Layer): string {
        const className = `layer-${layer.id}`;
        const styleContent = this.generateCSS(layer).replace(/\n/g, '\n  ');

        if (layer.layer_type === 'text') {
            return `<template>
  <div class="${className}">
    ${layer.name}
  </div>
</template>

<style scoped>
.${className} {
  ${styleContent}
}
</style>`;
        } else {
            return `<template>
  <div class="${className}"></div>
</template>

<style scoped>
.${className} {
  ${styleContent}
}
</style>`;
        }
    }

    static generateReact(layer: Layer): string {
        const styleObj = this.generateJS(layer);
        const styleString = JSON.stringify(styleObj, null, 2).replace(/"([^"]+)":/g, '$1:');

        if (layer.layer_type === 'text') {
            return `import React from 'react';

const Layer${layer.id} = () => {
  const style = ${styleString};

  return (
    <div style={style}>
      ${layer.name}
    </div>
  );
};

export default Layer${layer.id};`;
        } else {
            return `import React from 'react';

const Layer${layer.id} = () => {
  const style = ${styleString};

  return (
    <div style={style} />
  );
};

export default Layer${layer.id};`;
        }
    }

    static generateJS(layer: Layer): Record<string, string | number> {
        if (layer.layer_type === 'text') {
            return {
                fontFamily: layer.metadata?.font?.name || 'inherit',
                fontSize: `${layer.metadata?.font?.sizes?.[0] || 'inherit'}px`,
                color: layer.metadata?.font?.colors?.[0] ? `rgb(${layer.metadata.font.colors[0].join(',')})` : 'inherit',
                lineHeight: 1.5,
            };
        } else {
            return {
                width: `${layer.width}px`,
                height: `${layer.height}px`,
                backgroundImage: `url('${layer.name}.png')`,
                backgroundSize: 'cover',
            };
        }
    }
}
