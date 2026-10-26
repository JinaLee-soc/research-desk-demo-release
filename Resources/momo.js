"use strict";
window.Momo = (() => {
  const sheet = new Image();
  const frames = [[50,48,638,628],[760,48,646,628],[1480,48,640,628]];
  function paint(canvas, mood = 'idle') {
    if (!sheet.complete || !sheet.naturalWidth) return;
    const frame = frames[mood === 'critical' ? 2 : ['wave','waiting'].includes(mood) ? 1 : 0];
    const context = canvas.getContext('2d');
    context.clearRect(0,0,canvas.width,canvas.height);
    context.imageSmoothingEnabled = true;
    const size = Math.min(canvas.width,canvas.height);
    context.drawImage(sheet,...frame,(canvas.width-size)/2,(canvas.height-size)/2,size,size);
  }
  function paintAll() { document.querySelectorAll('canvas[data-pet],canvas.chat-pet').forEach(c=>paint(c,c.dataset.pet||'idle')); }
  sheet.onload = paintAll;
  sheet.src = 'momo-poses.png';
  return {paint,paintAll};
})();
