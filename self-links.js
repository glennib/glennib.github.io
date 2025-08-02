document.addEventListener("DOMContentLoaded", () => {
    document.querySelectorAll("section[id]").forEach(section => {
        const id = section.id;
        const heading = section.querySelector("h1, h2, h3, h4, h5, h6");
        if (heading && !heading.querySelector(".self-link")) {
            const link = document.createElement("a");
            link.href = `#${id}`;
            link.className = "self-link";
            link.setAttribute("aria-label", `Link to ${heading.textContent}`);
            link.textContent = "#";
            heading.appendChild(link);
        }
    });
});