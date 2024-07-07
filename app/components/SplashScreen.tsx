import React from "react";
import { motion } from "framer-motion";

interface DotProps {
  delay: number;
}

const Dot: React.FC<DotProps> = ({ delay }) => (
  <motion.div
    className="w-4 h-4 bg-indigo-600 dark:bg-indigo-300 rounded-full"
    initial={{ y: 0 }}
    animate={{
      y: [0, -20, 0],
      scale: [1, 1.1, 1],
    }}
    transition={{
      y: { duration: 0.5, delay },
      scale: { duration: 1, repeat: Infinity, delay: delay + 0.5 },
    }}
  />
);

const SplashScreen = () => (
  <div className="fixed inset-0 bg-gradient-to-br from-blue-50 to-indigo-100 dark:from-zinc-800 dark:to-slate-900 flex flex-col items-center justify-center z-50">
    <div className="text-6xl font-bold text-indigo-600 dark:text-indigo-300 mb-8">
      <span className="text-7xl">3</span> <span className="text-6xl">2</span>{" "}
      <span className="text-5xl">1</span>
    </div>
    <div className="text-3xl font-bold text-indigo-600 dark:text-indigo-300">
      Marchkov!
    </div>
    <div className="flex mt-12 space-x-2">
      <Dot delay={0} />
      <Dot delay={0.2} />
      <Dot delay={0.4} />
    </div>
  </div>
);

export default SplashScreen;
