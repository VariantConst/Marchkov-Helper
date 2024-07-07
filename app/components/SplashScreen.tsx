import React, { useState, useEffect } from "react";
import { motion, AnimatePresence } from "framer-motion";

const NumberAnimation = ({ number }) => (
  <motion.div
    key={number}
    initial={{ opacity: 0, scale: 0.5 }}
    animate={{ opacity: 1, scale: 1 }}
    exit={{ opacity: 0, scale: 0.5 }}
    transition={{ duration: 0.4 }}
    className="text-8xl font-bold text-indigo-600 dark:text-indigo-300"
  >
    {number}
  </motion.div>
);

const PulsingDots = () => (
  <span className="inline-flex space-x-1">
    {[0, 1, 2].map((i) => (
      <span
        key={i}
        className="w-2 h-2 bg-indigo-600 dark:bg-indigo-300 rounded-full"
        style={{
          animation: `pulse 1.5s infinite ease-in-out ${i * 0.3}s`,
        }}
      />
    ))}
  </span>
);

const SplashScreen = () => {
  const [currentNumber, setCurrentNumber] = useState(3);
  const [showMarchkov, setShowMarchkov] = useState(false);
  const [showFavicon, setShowFavicon] = useState(false);

  useEffect(() => {
    const timer = setTimeout(() => {
      if (currentNumber > 1) {
        setCurrentNumber(currentNumber - 1);
      } else {
        setCurrentNumber(null);
        setShowFavicon(true);
        setTimeout(() => setShowMarchkov(true), 100);
      }
    }, 500);

    return () => clearTimeout(timer);
  }, [currentNumber]);

  return (
    <div className="fixed inset-0 bg-gradient-to-br from-blue-50 to-indigo-100 dark:from-zinc-800 dark:to-slate-900 overflow-hidden">
      <div className="absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 w-32 h-32 rounded-full bg-white dark:bg-zinc-700 shadow-lg flex items-center justify-center overflow-hidden">
        <AnimatePresence mode="wait">
          {currentNumber !== null ? (
            <NumberAnimation number={currentNumber} />
          ) : showFavicon ? (
            <motion.img
              src="/favicon.png"
              alt="Favicon"
              className="object-contain mt-[0.2rem]"
              initial={{ opacity: 0, scale: 0.5 }}
              animate={{ opacity: 1, scale: 1 }}
              transition={{ duration: 0.4 }}
            />
          ) : null}
        </AnimatePresence>
      </div>

      <AnimatePresence>
        {showMarchkov && (
          <motion.div
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            exit={{ opacity: 0, y: -20 }}
            transition={{ duration: 0.5 }}
            className="absolute top-[60%] left-0 right-0 flex justify-center items-center"
          >
            <div className="text-4xl font-bold text-indigo-600 dark:text-indigo-300 flex items-center space-x-2 whitespace-nowrap">
              <span>Marchkov</span>
              <PulsingDots />
            </div>
          </motion.div>
        )}
      </AnimatePresence>
    </div>
  );
};

export default SplashScreen;
