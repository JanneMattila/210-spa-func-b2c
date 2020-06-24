using System.Collections.Immutable;

namespace Func
{
    public interface ISalesRepository
    {
        void Add(Sales sales);
        Sales Delete(string id);
        ImmutableList<Sales> Get();
        Sales Get(string id);
    }
}