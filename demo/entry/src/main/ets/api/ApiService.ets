import { http } from '@kit.NetworkKit';
import { getApiBaseUrl } from './ApiConfig';

export class ApiService {
  static get(path: string): Promise<string> {
    return new Promise((resolve, reject) => {
      const request = http.createHttp();
      const url: string = getApiBaseUrl() + path;
      console.log('[ApiService] GET ' + url);

      request.request(
        url,
        {
          method: http.RequestMethod.GET,
          connectTimeout: 15000,
          readTimeout: 15000
        },
        (error, data) => {
          request.destroy();

          if (error) {
            console.error('[ApiService] GET ' + url + ' ERROR: ' + error.message);
            reject(error);
            return;
          }

          console.log('[ApiService] GET ' + url + ' -> HTTP ' + data.responseCode + ' body=' + (data.result as string).substring(0, Math.min(200, (data.result as string).length)));
          resolve(data.result as string);
        }
      );
    });
  }

  static post(path: string, body: object): Promise<string> {
    return new Promise((resolve, reject) => {
      const request = http.createHttp();

      request.request(
        getApiBaseUrl() + path,
        {
          method: http.RequestMethod.POST,
          header: {
            'Content-Type': 'application/json'
          },
          extraData: JSON.stringify(body),
          connectTimeout: 15000,
          readTimeout: 15000
        },
        (error, data) => {
          request.destroy();

          if (error) {
            reject(error);
            return;
          }

          resolve(data.result as string);
        }
      );
    });
  }
  static put(path: string, body: object): Promise<string> {
    return new Promise((resolve, reject) => {
      const request = http.createHttp();

      request.request(
        getApiBaseUrl() + path,
        {
          method: http.RequestMethod.PUT,
          header: {
            'Content-Type': 'application/json'
          },
          extraData: JSON.stringify(body),
          connectTimeout: 15000,
          readTimeout: 15000
        },
        (error, data) => {
          request.destroy();

          if (error) {
            reject(error);
            return;
          }

          resolve(data.result as string);
        }
      );
    });
  }

  static delete(path: string): Promise<string> {
    return new Promise((resolve, reject) => {
      const request = http.createHttp();

      request.request(
        getApiBaseUrl() + path,
        {
          method: http.RequestMethod.DELETE,
          connectTimeout: 15000,
          readTimeout: 15000
        },
        (error, data) => {
          request.destroy();

          if (error) {
            reject(error);
            return;
          }

          resolve(data.result as string);
        }
      );
    });
  }

}
