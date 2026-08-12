import { useRef, useEffect } from 'react';
import Plotly from 'plotly.js-dist-min';

interface PlotProps {
  data: any[];
  layout?: Record<string, any>;
  config?: Record<string, any>;
  style?: React.CSSProperties;
}

export default function Plot({ data, layout = {}, config = {}, style = {} }: PlotProps) {
  const containerRef = useRef<HTMLDivElement>(null);
  const dataJson = JSON.stringify(data);
  const layoutJson = JSON.stringify(layout);

  useEffect(() => {
    if (!containerRef.current) return;

    const parsedData = JSON.parse(dataJson);
    const parsedLayout = JSON.parse(layoutJson);

    Plotly.react(containerRef.current, parsedData, parsedLayout, {
      displayModeBar: false,
      responsive: true,
      ...config,
    });
  }, [dataJson, layoutJson]);

  useEffect(() => {
    return () => {
      if (containerRef.current) {
        Plotly.purge(containerRef.current);
      }
    };
  }, []);

  return <div ref={containerRef} style={{ width: '100%', height: '340px', ...style }} />;
}
