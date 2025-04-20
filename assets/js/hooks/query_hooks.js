// Hooks for the query interface
const QueryHooks = {
  // Hook to highlight the response when it appears
  HighlightResponse: {
    mounted() {
      // Listen for the highlight-response event
      this.handleEvent("highlight-response", () => {
        // Add the highlight class
        this.el.classList.add("highlight-response");
        
        // Set up syntax highlighting for code blocks
        this.highlightCodeBlocks();
        
        // Remove the highlight after animation completes
        setTimeout(() => {
          this.el.classList.remove("highlight-response");
        }, 2000);
      });
    },
    
    // Helper method to apply syntax highlighting to code blocks
    highlightCodeBlocks() {
      const codeBlocks = this.el.querySelectorAll('pre code');
      
      // If hljs is available (you can add highlight.js via CDN), apply it
      if (window.hljs) {
        codeBlocks.forEach(block => {
          window.hljs.highlightElement(block);
        });
      }
    }
  },
  
  // Hook to scroll to the response section when a query is submitted
  QueryForm: {
    mounted() {
      this.handleEvent("scroll-to-response", () => {
        // First check if there's a loading section
        const loadingSection = document.getElementById("loading-section");
        const responseSection = document.getElementById("response-section");
        
        // Scroll to whichever section is visible
        const targetSection = loadingSection || responseSection;
        
        if (targetSection) {
          setTimeout(() => {
            targetSection.scrollIntoView({ behavior: "smooth", block: "start" });
          }, 100);
        }
      });
    }
  }
};

export default QueryHooks;
