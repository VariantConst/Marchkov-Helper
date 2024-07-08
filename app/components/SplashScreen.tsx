import React, { useState, useEffect } from "react";
import { motion, AnimatePresence } from "framer-motion";

interface NumberAnimationProps {
  number: number;
}

const NumberAnimation: React.FC<NumberAnimationProps> = ({ number }) => (
  <motion.div
    key={number}
    initial={{ opacity: 0, scale: 0.5 }}
    animate={{ opacity: 1, scale: 1 }}
    exit={{ opacity: 0, scale: 0.5 }}
    transition={{ duration: 0.2 }}
    className="text-8xl font-bold text-indigo-600 font-sans"
  >
    {number}
  </motion.div>
);

const EnhancedSplashScreen: React.FC = () => {
  const [currentNumber, setCurrentNumber] = useState<number | null>(3);
  const [showFavicon, setShowFavicon] = useState(false);

  useEffect(() => {
    const timer = setTimeout(() => {
      if (currentNumber !== null && currentNumber > 1) {
        setCurrentNumber(currentNumber - 1);
      } else {
        setCurrentNumber(null);
        setShowFavicon(true);
      }
    }, 500);

    return () => clearTimeout(timer);
  }, [currentNumber]);

  return (
    <div className="fixed inset-0 overflow-hidden flex items-center justify-center bg-gradient-to-br from-indigo-50 to-blue-100 font-sans">
      <style jsx global>{`
        @import url("https://fonts.googleapis.com/css2?family=Bungee+Shade&display=swap");
      `}</style>
      <div className="z-10 flex flex-col items-center">
        <motion.div
          className="w-40 h-40 rounded-full bg-white shadow-lg flex items-center justify-center overflow-hidden"
          animate={{
            boxShadow: [
              "0 0 0 0 rgba(79, 70, 229, 0.2)",
              "0 0 0 20px rgba(79, 70, 229, 0)",
            ],
          }}
          transition={{
            duration: 1.5,
            repeat: Infinity,
            ease: "easeInOut",
          }}
        >
          <AnimatePresence mode="wait">
            {currentNumber !== null ? (
              <NumberAnimation number={currentNumber} />
            ) : showFavicon ? (
              <motion.img
                src="/favicon.png"
                alt="Favicon"
                className="mt-[0.3rem] object-contain"
                initial={{ opacity: 0, scale: 0.5 }}
                animate={{ opacity: 1, scale: 1 }}
                transition={{ duration: 0.4 }}
              />
            ) : null}
          </AnimatePresence>
        </motion.div>

        <motion.div
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: showFavicon ? 1 : 0, y: showFavicon ? 0 : 20 }}
          transition={{ duration: 0.5, ease: "easeOut" }}
          className="mt-8 flex flex-col items-center"
        >
          <motion.div
            className="text-3xl font-semibold text-indigo-600 flex items-center space-x-2"
            initial={{ opacity: 0, scale: 0.8 }}
            animate={{
              opacity: showFavicon ? 1 : 0,
              scale: showFavicon ? 1 : 0.8,
            }}
            transition={{ duration: 0.5 }}
          >
            <span className="font-['Bungee_Shade'] text-4xl tracking-wider text-transparent bg-clip-text bg-gradient-to-r from-indigo-600 to-purple-600">
              Marchkov
            </span>
          </motion.div>
        </motion.div>
      </div>
    </div>
  );
};

export default EnhancedSplashScreen;
