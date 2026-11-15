(() => {
  let tesseractLoad;

  function loadTesseract() {
    if (globalThis.Tesseract) {
      return Promise.resolve(globalThis.Tesseract);
    }

    if (!tesseractLoad) {
      tesseractLoad = new Promise((resolve, reject) => {
        const script = document.createElement('script');
        script.src =
          'https://cdn.jsdelivr.net/npm/tesseract.js@6.0.1/dist/tesseract.min.js';
        script.crossOrigin = 'anonymous';
        script.onload = () => {
          if (globalThis.Tesseract) {
            resolve(globalThis.Tesseract);
          } else {
            tesseractLoad = undefined;
            reject(new Error('The browser OCR engine could not be loaded.'));
          }
        };
        script.onerror = () => {
          tesseractLoad = undefined;
          reject(new Error('Could not download the browser OCR engine.'));
        };
        document.head.appendChild(script);
      });
    }

    return tesseractLoad;
  }

  globalThis.cyvoraExtractScreenshotText = async (imageBytes) => {
    const tesseract = await loadTesseract();
    const worker = await tesseract.createWorker('eng');
    try {
      const { data } = await worker.recognize(imageBytes);
      return data.text || '';
    } finally {
      await worker.terminate();
    }
  };
})();
