/* global axios */
import ApiClient from './ApiClient';

class PantryclubAPI extends ApiClient {
  constructor() {
    super('contacts', { accountScoped: true });
  }

  getCustomer(contactId) {
    return axios.get(`${this.url}/${contactId}/pantryclub`);
  }
}

export default new PantryclubAPI();
