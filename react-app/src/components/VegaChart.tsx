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

    // Fill the available width. The chat panel is resizable, so let Vega track
    // the container instead of pinning a pixel width at embed time.
    parsedSpec.width = 'container';
    parsedSpec.height = 250;
    parsedSpec.autosize = { type: 'fit', contains: 'padding' };
    // Matches the assistant message bubble the chart renders inside.
    parsedSpec.background = '#F5F2ED';
    parsedSpec.config = {
      ...parsedSpec.config,
      axis: {
        labelColor: '#4b5563',
        titleColor: '#1f2937',
        gridColor: '#E0DBD3',
        domainColor: '#C8C1B8',
      },
      legend: { labelColor: '#4b5563', titleColor: '#1f2937' },
      title: { color: '#1f2937' },
      view: { stroke: 'transparent' },
    };

    // Tear the view down on unmount or re-spec, otherwise every chart the agent
    // returns leaves a live Vega view behind for the life of the session.
    let result: { finalize: () => void } | null = null;
    let cancelled = false;

    embed(containerRef.current, parsedSpec, { actions: false })
      .then((r) => {
        if (cancelled) {
          r.finalize();
          return;
        }
        result = r;
      })
      .catch(console.error);

    return () => {
      cancelled = true;
      result?.finalize();
    };
  }, [spec]);

  return <div ref={containerRef} className="w-full mt-2 rounded overflow-hidden" />;
}
