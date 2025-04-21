// JavaScript hooks for LiveView

// Hook to handle session management
const SessionManager = {
  mounted() {
    // When the component mounts, check if we have a stored session ID
    const storedSessionId = localStorage.getItem("ragSessionId");

    if (storedSessionId) {
      // Push an event to the server to restore the session
      this.pushEvent("restore_session", { session_id: storedSessionId });
    }

    // Listen for store-session events from the server
    this.handleEvent("store-session", ({ session_id }) => {
      localStorage.setItem("ragSessionId", session_id);
    });

    // Add window unload event listener to clean up when navigating away
    window.addEventListener("beforeunload", this._handleUnload);
  },

  destroyed() {
    // Remove event listener when component is unmounted
    window.removeEventListener("beforeunload", this._handleUnload);
  },

  _handleUnload() {
    // This will trigger the session to be cleaned up on the server side
    // No need to send an event, as the LiveView terminate callback will handle this
    // We could make a synchronous request here, but it's not necessary as
    // the server will clean up inactive sessions regularly
  },
};

// Hook to handle query form behavior
const QueryForm = {
  mounted() {
    // Clear the form after submission
    this.el.addEventListener("submit", () => {
      // const textarea = this.el.querySelector("textarea");
      // We'll let the server clear the input by updating the value
      // This ensures we maintain the value until processing completes
    });
  },
};

// Hook to scroll to the response section
document.addEventListener("phx:scroll-to-response", (e) => {
  // Scroll to the response or loading section
  const responseSection =
    document.getElementById("loading-section") ||
    document.getElementById("response-section");

  if (responseSection) {
    responseSection.scrollIntoView({ behavior: "smooth", block: "center" });
  }
});

// Hook to highlight the response content (for syntax highlighting if needed)
const HighlightResponse = {
  mounted() {
    // Apply any syntax highlighting or formatting here
    this.handleEvent("highlight-response", () => {
      // Could add code here to enhance markdown rendering
      // or apply syntax highlighting to code blocks
    });
  },
};

export default {
  SessionManager,
  QueryForm,
  HighlightResponse,
};
