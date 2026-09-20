/**
 * Simple wrapper around fetch API tailored for CEF/NUI use. This abstraction
 * can be extended to include AbortController if needed or if the response isn't
 * JSON. Tailor it to your needs.
 *
 * @param eventName - The endpoint eventname to target
 * @param data - Data you wish to send in the NUI Callback
 *
 * @return returnData - A promise for the data sent back by the NuiCallbacks CB argument,
 *                      or null when the callback could not answer.
 */

const fetch = window.fetch;
// @ts-expect-error
window.fetch = () => {};
// @ts-expect-error
window.XMLHttpRequest = window.fetch;

/**
 * ⚠️ Reported names, so a missing callback costs one console line rather than one per call.
 *    A menu that reopens fifty times must not print fifty warnings.
 */
const reported = new Set<string>();

const reportOnce = (eventName: string, resourceName: string, reason: string) => {
  const key = `${resourceName}/${eventName}`;

  if (reported.has(key)) return;

  reported.add(key);
  console.warn(`[w_lib] fetchNui('${eventName}') on resource '${resourceName}': ${reason}`);
};

export async function fetchNui<T = any>(eventName: string, data?: any): Promise<T | null> {
  const options = {
    method: 'post',
    headers: {
      'Content-Type': 'application/json; charset=UTF-8',
    },
    /* ⚠️ `data ?? {}`, because JSON.stringify(undefined) is the value undefined rather than a
       string -- a data-less call would declare a JSON content type and then send no body. */
    body: JSON.stringify(data ?? {}),
  };

  /**
   * ⚠️ The resource that OWNS this frame, which is not always w_lib.
   *
   *    A consumer that points its own ui_page at nui://w_lib/web/build/index.html gets its own
   *    CEF browser running this same app, and GetParentResourceName() then returns the consumer.
   *    Its callbacks are whatever that resource registered -- for a resource borrowing the frame
   *    only as a surface for SendNUIMessage, that is none of w_lib's.
   */
  const resourceName = (window as any).GetParentResourceName
    ? (window as any).GetParentResourceName()
    : 'nui-frame-app';

  const resp = await fetch(`https://${resourceName}/${eventName}`, options);

  /**
   * ⚠️ Read as text and decide, rather than handing the body straight to resp.json().
   *
   *    RedM answers a POST for a callback the owning resource never registered with 200 and a
   *    ZERO-LENGTH body -- so resp.ok is no help, the empty body is the tell. json() on it
   *    rejects with `SyntaxError: Unexpected end of JSON input`, and because that error names
   *    neither the event nor the resource, CEF could only attribute it to `index.html:1`. Two
   *    contentless red lines on every boot of a borrowed frame, saying nothing about the cause.
   *
   * ★ A callback that cannot answer returns null and names itself once. A missing handler is a
   *   misconfiguration to be read and fixed, not an exception that unwinds whatever called it.
   */
  if (!resp.ok) {
    reportOnce(eventName, resourceName, `HTTP ${resp.status} ${resp.statusText}`);
    return null;
  }

  const body = await resp.text();

  if (!body) {
    reportOnce(eventName, resourceName, 'empty reply — that resource registers no NUI callback by this name');
    return null;
  }

  try {
    return JSON.parse(body) as T;
  } catch {
    reportOnce(eventName, resourceName, `reply was not JSON: ${body.slice(0, 120)}`);
    return null;
  }
}
