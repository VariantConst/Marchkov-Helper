import React, { useState, useEffect } from "react";
import { motion, AnimatePresence } from "framer-motion";

const RefinedLoadingOverlay = ({ isLoading }) => {
  const [count, setCount] = useState(3);
  const [showMarkov, setShowMarkov] = useState(false);

  useEffect(() => {
    let timer;
    if (isLoading && count > 0) {
      timer = setTimeout(() => setCount(count - 1), 1000);
    } else if (count === 0) {
      setShowMarkov(true);
    }
    return () => clearTimeout(timer);
  }, [isLoading, count]);

  useEffect(() => {
    if (!isLoading) {
      setCount(3);
      setShowMarkov(false);
    }
  }, [isLoading]);

  const numberVariants = {
    initial: {
      opacity: 0,
      y: 50,
      scale: 0.5,
    },
    animate: {
      opacity: 1,
      y: 0,
      scale: 1,
      transition: {
        duration: 0.5,
        ease: "easeOut",
      },
    },
    exit: {
      opacity: 0,
      y: -50,
      scale: 0.5,
      transition: {
        duration: 0.5,
        ease: "easeIn",
      },
    },
  };

  const dotVariants = {
    animate: (i) => ({
      opacity: [0.3, 1, 0.3],
      scale: [1, 1.2, 1],
      transition: {
        duration: 1.5,
        repeat: Infinity,
        delay: i * 0.2,
      },
    }),
  };

  return (
    <AnimatePresence>
      {isLoading && (
        <motion.div
          initial={{ opacity: 0 }}
          animate={{ opacity: 1 }}
          exit={{ opacity: 0 }}
          className="fixed inset-0 bg-[#4e73c2] flex items-center justify-center z-50"
        >
          <div className="text-[#e3f9fd] text-8xl md:text-9xl font-bold flex flex-col items-center">
            {!showMarkov ? (
              <div className="relative h-60 w-60 flex items-center justify-center">
                <AnimatePresence mode="popLayout">
                  <motion.div
                    key={count}
                    variants={numberVariants}
                    initial="initial"
                    animate="animate"
                    exit="exit"
                    className="absolute"
                  >
                    {count}
                  </motion.div>
                </AnimatePresence>
              </div>
            ) : (
              <div className="flex items-center space-x-4 text-4xl md:text-6xl">
                <span className="bg-clip-text text-transparent bg-gradient-to-r from-[#e3f9fd] to-[#a0e7f5]">
                  Markov
                </span>
                <div className="flex items-center">
                  {[0, 1, 2].map((i) => (
                    <motion.span
                      key={i}
                      variants={dotVariants}
                      animate="animate"
                      custom={i}
                      className="w-3 h-3 mx-1 rounded-full bg-[#e3f9fd]"
                    />
                  ))}
                </div>
              </div>
            )}
          </div>
        </motion.div>
      )}
    </AnimatePresence>
  );
};

export default RefinedLoadingOverlay;
