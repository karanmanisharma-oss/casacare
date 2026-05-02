import React from 'react';
import { createRoot } from 'react-dom/client';
import CasaCareApp from '../casa-care-app.jsx';

createRoot(document.getElementById('root')).render(
  <React.StrictMode>
    <CasaCareApp />
  </React.StrictMode>
);
