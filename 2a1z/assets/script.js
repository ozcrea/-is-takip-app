(function(){
  var reduced = window.matchMedia('(prefers-reduced-motion: reduce)').matches;

  function splitWords(el){
    if(!el || el.dataset.split) return;
    el.dataset.split = '1';
    var text = el.textContent;
    el.setAttribute('aria-label', text);
    el.innerHTML = '';
    var tokens = text.split(/(\s+)/);
    tokens.forEach(function(tok){
      if(/^\s+$/.test(tok)){
        el.appendChild(document.createTextNode(tok));
      } else if(tok.length){
        var span = document.createElement('span');
        span.className = 'word';
        span.textContent = tok;
        span.setAttribute('aria-hidden','true');
        el.appendChild(span);
      }
    });
  }

  function armWords(el, startDelay, stepMs){
    if(!el) return startDelay;
    var words = el.querySelectorAll('.word');
    words.forEach(function(w,i){ w.style.transitionDelay = (startDelay + i*stepMs) + 'ms'; });
    return startDelay + words.length * stepMs;
  }

  function play(el){
    if(!el) return;
    requestAnimationFrame(function(){
      requestAnimationFrame(function(){
        el.querySelectorAll('.word').forEach(function(w){ w.classList.add('v'); });
        el.classList.add('v');
      });
    });
  }

  document.querySelectorAll('.reveal-text').forEach(splitWords);

  function revealSection(section){
    if(reduced){
      section.querySelectorAll('.word').forEach(function(w){ w.classList.add('v'); });
      section.querySelectorAll('.eyebrow,.divider,.fade-up').forEach(function(el){ el.classList.add('v'); });
      return;
    }
    var eyebrow = section.querySelector('.eyebrow');
    var divider = section.querySelector('.divider');
    var heading = section.querySelector('.reveal-text.heading');
    var sub = section.querySelector('.reveal-text.sub');
    var fadeUps = section.querySelectorAll('.fade-up');

    // Timings overlap deliberately (sub starts while the heading is still
    // materializing) and every per-item step is capped, so a content-heavy
    // section (long heading + many cards) still settles in ~1.1s instead of
    // chaining into a multi-second blank wait.
    if(eyebrow){ setTimeout(function(){ eyebrow.classList.add('v'); }, 0); }
    if(divider){ setTimeout(function(){ divider.classList.add('v'); }, 150); }
    if(heading){ armWords(heading, 250, 22); play(heading); }
    if(sub){ armWords(sub, heading ? 340 : 250, 8); play(sub); }

    var fadeBase = 520;
    fadeUps.forEach(function(el, i){ el.style.transitionDelay = (fadeBase + Math.min(i,5)*70) + 'ms'; });
    requestAnimationFrame(function(){
      requestAnimationFrame(function(){
        fadeUps.forEach(function(el){ el.classList.add('v'); });
      });
    });

    var counters = section.querySelectorAll('[data-count]');
    counters.forEach(function(c){
      var target = parseInt(c.getAttribute('data-count'),10);
      var start = null;
      var dur = 900;
      setTimeout(function(){
        function step(ts){
          if(!start) start = ts;
          var p = Math.min((ts-start)/dur, 1);
          c.textContent = Math.round(p*target);
          if(p<1) requestAnimationFrame(step);
        }
        requestAnimationFrame(step);
      }, fadeBase);
    });
  }

  var hero = document.querySelector('[data-hero]');
  window.addEventListener('DOMContentLoaded', function(){
    if(hero) revealSection(hero);
  });

  var io = new IntersectionObserver(function(entries){
    entries.forEach(function(entry){
      if(entry.isIntersecting){
        revealSection(entry.target);
        io.unobserve(entry.target);
      }
    });
  }, { threshold:0.18, rootMargin:'0px 0px -8% 0px' });

  document.querySelectorAll('[data-reveal]').forEach(function(sec){
    if(sec !== hero) io.observe(sec);
  });

  var progress = document.getElementById('progress');
  var rings = document.querySelectorAll('.hero .ring, .page-hero .ring');
  function onScroll(){
    var h = document.documentElement;
    var scrolled = h.scrollTop;
    var max = h.scrollHeight - h.clientHeight;
    if(progress) progress.style.width = (max>0 ? (scrolled/max*100) : 0) + '%';
    if(!reduced){
      rings.forEach(function(r,i){
        r.style.transform = 'translateY(' + (scrolled * (0.06 + i*0.03)) + 'px)';
      });
    }
  }
  document.addEventListener('scroll', onScroll, { passive:true });
  onScroll();

  var menuBtn = document.getElementById('menuBtn');
  var mobileMenu = document.getElementById('mobileMenu');
  if(menuBtn && mobileMenu){
    menuBtn.addEventListener('click', function(){
      var open = mobileMenu.classList.toggle('open');
      menuBtn.setAttribute('aria-expanded', open ? 'true' : 'false');
    });
    mobileMenu.querySelectorAll('a').forEach(function(a){
      a.addEventListener('click', function(){
        mobileMenu.classList.remove('open');
        menuBtn.setAttribute('aria-expanded','false');
      });
    });
  }

  var form = document.getElementById('contactForm');
  if(form){
    form.addEventListener('submit', function(e){
      e.preventDefault();
      var confirmBox = document.getElementById('formConfirm');
      if(confirmBox) confirmBox.classList.add('show');
      form.reset();
    });
  }
})();
