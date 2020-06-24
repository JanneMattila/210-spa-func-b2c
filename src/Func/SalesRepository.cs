using System.Collections.Generic;
using System.Collections.Immutable;
using System.Linq;

namespace Func
{
    public class SalesRepository : ISalesRepository
    {
        private List<Sales> _sales = new List<Sales>();

        public SalesRepository()
        {
            for (int i = 1; i <= 10; i++)
            {
                _sales.Add(
                    new Sales()
                    {
                        ID = i.ToString(),
                        Name = $"Item {i}",
                        Price = 100 + i
                    });
            }
        }

        public void Add(Sales sales)
        {
            _sales.Add(sales);
        }

        public ImmutableList<Sales> Get()
        {
            return _sales.ToImmutableList();
        }

        public Sales Get(string id)
        {
            return _sales.FirstOrDefault(s => s.ID == id);
        }

        public Sales Delete(string id)
        {
            var s = Get(id);
            if (s != null)
            {
                _sales.Remove(s);
                return s;
            }
            return null;
        }
    }
}
