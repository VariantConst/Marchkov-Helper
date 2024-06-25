import React, { useState, useEffect } from "react";

const LoadingAnimation = ({ isLoading, onAnimationComplete }) => {
  const [count, setCount] = useState(3);
  const [showLoading, setShowLoading] = useState(false);

  useEffect(() => {
    if (!isLoading) {
      setCount(3);
      setShowLoading(false);
      return;
    }

    if (count > 0) {
      const timer = setTimeout(() => setCount(count - 1), 1000);
      return () => clearTimeout(timer);
    } else if (count === 0) {
      setShowLoading(true);
      onAnimationComplete();
    }
  }, [isLoading, count, onAnimationComplete]);

  if (!isLoading) return null;

  return (
    <div className="fixed inset-0 bg-black bg-opacity-75 flex items-center justify-center z-50">
      {count > 0 ? (
        <div className="text-white text-9xl font-bold animate-pulse">
          {count}
        </div>
      ) : showLoading ? (
        <div className="text-white text-4xl">
          <div className="animate-spin rounded-full h-32 w-32 border-t-2 border-b-2 border-white"></div>
        </div>
      ) : null}
    </div>
  );
};

export default LoadingAnimation;
