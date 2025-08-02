document.addEventListener("DOMContentLoaded", () => {
    const toc = document.getElementById("toc");
    if (!toc) {
        return;
    }
    const sections = document.querySelectorAll("section");

    const list = document.createElement("ul");

    sections.forEach(section => {
        const header = section.querySelector("h1, h2, h3, h4, h5, h6");
        if (header && section.id) {
            const li = document.createElement("li");
            const link = document.createElement("a");
            link.href = `#${section.id}`;
            link.textContent = header.textContent.slice(0, -1);
            li.appendChild(link);
            list.appendChild(li);
        }
    });

    toc.appendChild(list);
});
