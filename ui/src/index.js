import { CssBaseline } from "@mui/material";
import React from "react";
import ReactDOM from "react-dom";
import App from "./App";
import { EthereumProviderProvider } from "./EthereumProviderContext";

ReactDOM.render(
  <React.StrictMode>
    <CssBaseline />
    <EthereumProviderProvider>
      <App />
    </EthereumProviderProvider>
  </React.StrictMode>,
  document.getElementById("root")
);
