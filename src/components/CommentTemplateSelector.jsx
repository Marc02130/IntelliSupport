import { useState, useEffect } from 'react';
import { supabase } from '../lib/supabaseClient';

export default function CommentTemplateSelector({ onSelect }) {
  const [templates, setTemplates] = useState([]);
  const [categories, setCategories] = useState([]);
  const [selectedCategory, setSelectedCategory] = useState('');
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);

  useEffect(() => {
    loadTemplates();
  }, []);

  const loadTemplates = async () => {
    try {
      setLoading(true);
      const { data, error } = await supabase
        .from('comment_templates')
        .select('*')
        .order('category')
        .order('sort_order');

      if (error) throw error;

      setTemplates(data);
      
      // Extract unique categories
      const uniqueCategories = [...new Set(data.map(t => t.category))];
      setCategories(uniqueCategories);
      
      if (uniqueCategories.length > 0) {
        setSelectedCategory(uniqueCategories[0]);
      }
    } catch (err) {
      setError(err.message);
    } finally {
      setLoading(false);
    }
  };

  const handleTemplateSelect = (template) => {
    onSelect(template);
  };

  if (loading) return <div>Loading templates...</div>;
  if (error) return <div>Error loading templates: {error}</div>;

  return (
    <div className="comment-template-selector">
      <div className="category-selector">
        <select
          value={selectedCategory}
          onChange={(e) => setSelectedCategory(e.target.value)}
          className="block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm dark:bg-gray-700 dark:border-gray-600"
        >
          {categories.map(category => (
            <option key={category} value={category}>{category}</option>
          ))}
        </select>
      </div>

      <div className="templates-list mt-2 space-y-2">
        {templates
          .filter(t => t.category === selectedCategory)
          .map(template => (
            <button
              key={template.id}
              onClick={() => handleTemplateSelect(template)}
              className="block w-full text-left px-4 py-2 text-sm text-gray-700 hover:bg-gray-100 hover:text-gray-900 dark:text-gray-200 dark:hover:bg-gray-600"
            >
              {template.name}
              {template.is_private && (
                <span className="ml-2 text-xs text-gray-500">(Private)</span>
              )}
            </button>
          ))}
      </div>

      <style jsx>{`
        .comment-template-selector {
          border: 1px solid #e5e7eb;
          border-radius: 0.375rem;
          padding: 1rem;
          background-color: white;
          dark:background-color: #1f2937;
        }

        .templates-list {
          max-height: 200px;
          overflow-y: auto;
        }
      `}</style>
    </div>
  );
} 