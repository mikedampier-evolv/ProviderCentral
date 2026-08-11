import { useRef, useEffect } from 'react';
import embed from 'vega-embed';

interface VegaChartProps {
  spec: string;
}

export default function VegaChart({ spec }: VegaChartProps) {
  const containerRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    if (!containerRef.current || !spec) return;

    let parsedSpec: any;
    try {
      parsedSpec = JSON.parse(spec);
    } catch {
      return;
    }

    // Make chart fill available width
    parsedSpec.width = 'container';
    parsedSpec.height = 250;
    parsedSpec.autosize = { type: 'fit', contains: 'padding' };
    parsedSpec.background = '#1a1a1a';
    parsedSpec.config = {
      ...parsedSpec.config,
      axis: {
        labelColor: '#a0a0a0',
        titleColor: '#c0c0c0',
        gridColor: '#333',
        domainColor: '#555',
      },
      legend: { labelColor: '#a0a0a0', titleColor: '#c0c0c0' },
      title: { color: '#e0e0e0' },
      view: { stroke: 'transparent' },
    };

    embed(containerRef.current, parsedSpec, {
      actions: false,
      theme: 'dark',
      width: containerRef.current.clientWidth - 20,
    }).catch(console.error);
  }, [spec]);

  return <div ref={containerRef} className="w-full mt-2 rounded overflow-hidden" />;
}
