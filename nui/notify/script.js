const notificationsContainer = document.getElementById(
  "notifications-container"
);
const MAX_NOTIFICATIONS = 5; // الحد الأقصى للإشعارات النشطة في نفس الوقت
const textContainer = document.getElementById("text-container");
const activeTexts = {};
let text2DElement = null;

// ★ كان "nui://w_notify/nui/imgs/" — ومورد w_notify لم يعد موجودًا: دُمج
//   في w_lib (nui/notify). فكلُّ أيقونةٍ تُطلب باسمها — tick و cross و
//   warning — كانت تُحلّ إلى عنوانٍ ميّت فلا تُرسم شيئًا. ولأنّ العنصر
//   يبقى في الصفحة بلا صورة، بدا الإشعار «نصًّا بلا أيقونة» لا معطوبًا،
//   فعاش العطب طويلًا. الإشعارات التي تُمرّر مسارًا كاملًا لم تتأثّر.
const baseIconPath = "nui://w_lib/nui/notify/imgs/";

window.addEventListener("message", (event) => {
  const data = event.data;

  if (data.action === "drawText3D") {
    if (activeTexts[data.id]) {
      const textElement = activeTexts[data.id];
      textElement.style.left = `${data.x * window.innerWidth}px`;
      textElement.style.top = `${data.y * window.innerHeight}px`;
    } else {
      const textElement = document.createElement("div");
      textElement.className = "text3d";
      textElement.style.left = `${data.x * window.innerWidth}px`;
      textElement.style.top = `${data.y * window.innerHeight}px`;
      textElement.textContent = data.text;

      textContainer.appendChild(textElement);
      activeTexts[data.id] = textElement;
    }
  } else if (data.action === "removeText3D") {
    if (activeTexts[data.id]) {
      textContainer.removeChild(activeTexts[data.id]);
      delete activeTexts[data.id];
    }
  } else if (data.action === "drawText2D") {
    if (!text2DElement) {
      text2DElement = document.createElement("div");
      text2DElement.id = "text-2d";
      text2DElement.className = "text2d";
      textContainer.appendChild(text2DElement);
    }
    text2DElement.textContent = data.text;
  } else if (data.action === "removeText2D") {
    if (text2DElement) {
      textContainer.removeChild(text2DElement);
      text2DElement = null;
    }
  }  else if (data.action === "showNotification") {
    if (notificationsContainer.children.length >= MAX_NOTIFICATIONS) {
        notificationsContainer.removeChild(notificationsContainer.firstChild);
    }

    const notification = document.createElement("div");
    notification.className = "notification";
    if (data.useBackground) {
        notification.classList.add("useBackground");
    }
    notification.style.color = data.titleColor;

    const icon = document.createElement("div");
    icon.className = "icon";

    if (data.icon) {
        // يقبل مساراً كاملاً (nui:// أو http) كما هو، أو اسم أيقونة من مجلّد imgs
        const iconSrc = data.icon.includes("://") ? data.icon : `${baseIconPath}${data.icon}.png`;
        icon.style.backgroundImage = `url(${iconSrc})`;
    }

    const content = document.createElement("div");
    content.className = "content";
    content.style.textAlign = data.contentAlignment;
    content.innerHTML = `<h1 style="color: ${data.titleColor}">${data.title}</h1>
                         <p style="color: ${data.descriptionColor}">${data.description}</p>`;

    notification.appendChild(icon);
    notification.appendChild(content);
    notificationsContainer.appendChild(notification);

    const sound = document.getElementById("notify-sound");
    sound.volume = 0.1;
    sound.currentTime = 0;
    sound.play().catch((e) => {
        console.warn("Failed to play notify sound:", e);
    });
    
    if (data.duration < 9999999) {
        setTimeout(() => {
            notification.style.animation = "fadeOut 0.5s ease-out forwards";
            setTimeout(() => {
                if (notification.parentNode === notificationsContainer) {
                    notificationsContainer.removeChild(notification);
                }
            }, 500);
        }, data.duration);
    }
}
else if (data.action === "clearNotifications") {
    notificationsContainer.innerHTML = "";
  }
});
