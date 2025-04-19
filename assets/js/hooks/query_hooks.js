// Hooks for the query interface
const QueryHooks = {
  // Hook to highlight the response when it appears
  HighlightResponse: {
    mounted() {
      // Listen for the highlight-response event
      this.handleEvent("highlight-response", () => {
        this.el.classList.add("bg-yellow-50");
        setTimeout(() => {
          this.el.classList.remove("bg-yellow-50");
        }, 1000);
      });
    }
  },
  
  // Hook to scroll to the response section when a query is submitted
  QueryForm: {
    mounted() {
      this.handleEvent("scroll-to-response", () => {
        const responseSection = document.getElementById("response-section");
        if (responseSection) {
          responseSection.scrollIntoView({ behavior: "smooth", block: "start" });
        }
      });
    }
  }
};

export default QueryHooks;
