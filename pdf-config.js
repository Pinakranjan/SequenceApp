module.exports = {
  stylesheet: [
    'https://cdnjs.cloudflare.com/ajax/libs/github-markdown-css/4.0.0/github-markdown.min.css',
    'https://cdnjs.cloudflare.com/ajax/libs/highlight.js/10.7.2/styles/github.min.css'
  ],
  css: `
    .markdown-body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif; }
    .mermaid { display: flex; justify-content: center; margin: 20px 0; }
    table { width: 100%; border-collapse: collapse; }
    th, td { border: 1px solid #dfe2e5; padding: 6px 13px; }
    tr:nth-child(2n) { background-color: #f6f8fa; }
  `,
  body_class: 'markdown-body',
  pdf_options: {
    format: 'A4',
    margin: '20mm',
    printBackground: true,
  },
  script: [
    { url: 'https://cdn.jsdelivr.net/npm/mermaid@10.9.0/dist/mermaid.min.js' },
    { content: `
      // Initialize mermaid
      mermaid.initialize({ startOnLoad: false, theme: 'default' });

      // Find all code blocks with language-mermaid
      const mermaidBlocks = document.querySelectorAll('code.language-mermaid');
      
      mermaidBlocks.forEach((block, index) => {
        const content = block.textContent;
        const pre = block.parentElement;
        const div = document.createElement('div');
        div.className = 'mermaid';
        div.textContent = content;
        div.id = 'mermaid-' + index;
        
        // Replace the pre element with the new div
        pre.parentElement.replaceChild(div, pre);
      });

      // Run mermaid on the new divs
      mermaid.run().then(() => {
        // Signal that we are done (optional, but good for timing)
         document.body.classList.add('mermaid-rendered');
      });
    `}
  ]
};
