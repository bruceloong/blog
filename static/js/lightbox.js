// Lightbox implementation
document.addEventListener("DOMContentLoaded", function() {
  const galleryLinks = document.querySelectorAll(".gallery-item a");
  
  if (galleryLinks.length > 0) {
    galleryLinks.forEach(link => {
      link.addEventListener("click", function(e) {
        e.preventDefault();
        
        const imgSrc = this.getAttribute("href");
        const lightbox = document.createElement("div");
        lightbox.className = "lightbox";
        lightbox.innerHTML = `
          <div class="lightbox-content">
            <img src="${imgSrc}" alt="">
            <button class="lightbox-close">&times;</button>
          </div>
        `;
        
        document.body.appendChild(lightbox);
        document.body.style.overflow = "hidden";
        
        lightbox.addEventListener("click", function(e) {
          if (e.target.className === "lightbox" || e.target.className === "lightbox-close") {
            document.body.removeChild(lightbox);
            document.body.style.overflow = "";
          }
        });
      });
    });
  }
});
