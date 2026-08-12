/**
 * plotly.js-dist-min ships no type declarations.
 *
 * Plot.tsx uses exactly two functions from it, so they are declared here
 * rather than adding @types/plotly.js — that would type-check every trace and
 * layout object across the dashboard pages, which currently pass plain `any`.
 * Widen this if more of the Plotly surface gets used.
 */
declare module 'plotly.js-dist-min' {
  export function react(
    el: HTMLElement,
    data: unknown[],
    layout?: Record<string, unknown>,
    config?: Record<string, unknown>,
  ): Promise<unknown>;

  export function purge(el: HTMLElement): void;

  const Plotly: {
    react: typeof react;
    purge: typeof purge;
  };

  export default Plotly;
}
