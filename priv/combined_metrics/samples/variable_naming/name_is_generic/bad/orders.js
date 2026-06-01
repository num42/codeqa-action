class OrderProcessor {
  process(data) {
    const result = data.reduce((acc, item) => {
      const val = item.price * item.quantity;
      const tmp = { id: item.id, total: val, status: item.status };

      let obj;
      if (val > 100) {
        const x = this.applyDiscount(tmp, 0.1);
        obj = this.addTax(x, 0.2);
      } else {
        obj = this.addTax(tmp, 0.2);
      }

      acc.push(obj);
      return acc;
    }, []);

    return result;
  }

  applyDiscount(obj, val) {
    const tmp = obj.total * (1 - val);
    return { ...obj, total: tmp };
  }

  addTax(obj, val) {
    const tmp = obj.total * (1 + val);
    return { ...obj, total: tmp };
  }

  filter(data, val) {
    return data.filter(item => item.total > val);
  }

  summarize(data) {
    const result = data.map(item => {
      const tmp = Math.round(item.total * 100) / 100;
      return { id: item.id, total: tmp, status: item.status };
    });

    const info = result.reduce((acc, item) => acc + item.total, 0);

    return { items: result, sum: info };
  }

  group(data, val) {
    return data.reduce((acc, item) => {
      const key = item.total > val ? 'high' : 'low';
      if (!acc[key]) acc[key] = [];
      acc[key].push(item);
      return acc;
    }, {});
  }

  validate(data) {
    return data.filter(item => {
      const result = item.price > 0 && item.quantity > 0 && item.status != null;
      return result;
    });
  }

  enrich(data, obj) {
    return data.map(item => {
      const tmp = obj[item.id] || {};
      const val = { ...item, ...tmp };
      return val;
    });
  }

  formatOutput(data) {
    return data.map(item => {
      const tmp = {
        id: item.id,
        total: `$${item.total.toFixed(2)}`,
        status: item.status.toUpperCase()
      };
      return tmp;
    });
  }

  sort(data, val) {
    return [...data].sort((a, b) => a[val] - b[val]);
  }

  paginate(data, obj) {
    const info = obj.page || 1;
    const tmp = obj.perPage || 10;
    const val = (info - 1) * tmp;
    return data.slice(val, val + tmp);
  }
}

module.exports = OrderProcessor;
