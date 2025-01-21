import React, { useState, useEffect } from 'react'
import { useNavigate } from 'react-router-dom'
import { supabase } from '../lib/supabaseClient'

export default function Sidebar({ isSidebarCollapsed, setIsSidebarCollapsed, userRole }) {
  const [navItems, setNavItems] = useState([])
  const [expandedItems, setExpandedItems] = useState({})
  const navigate = useNavigate()

  // Log when component renders
  console.log('Sidebar component rendering with navItems:', navItems)

  useEffect(() => {
    console.log('Navigation useEffect running')
    const initNavigation = async () => {
      try {
        // Wait for session to be initialized
        const { data: { session } } = await supabase.auth.getSession()
        if (!session) {
          console.error('No session found - cannot load navigation')
          return
        }
        console.log('Session found:', session)
        console.log('User role:', userRole)

        // Load navigation items with error handling
        console.log('Fetching navigation data...')
        const { data, error } = await supabase
          .rpc('get_user_navigation', { p_role: userRole })

        if (error) {
          console.error('Database error loading navigation:', error.message, error.details, error.hint)
          return
        }

        console.log('Raw navigation data:', data)
        if (!data || data.length === 0) {
          console.error('No navigation data received from database')
          return
        }

        // Build and set navigation tree
        console.log('Building navigation tree from', data.length, 'items')
        const tree = buildNavigationTree(data)
        console.log('Built navigation tree:', tree)
        
        if (!tree || tree.length === 0) {
          console.error('Navigation tree is empty after building')
          return
        }

        console.log('Setting navItems with tree:', tree)
        setNavItems(tree)
        console.log('navItems state set')
      } catch (err) {
        console.error('Unexpected error in initNavigation:', err)
      }
    }

    initNavigation()
  }, [userRole])

  // Add debug effect for navItems state
  useEffect(() => {
    console.log('Current navItems state:', navItems)
  }, [navItems])

  const buildNavigationTree = (items) => {
    if (!items || items.length === 0) {
      console.log('No items to build tree from')
      return []
    }
    
    // Debug input
    console.log('buildNavigationTree input:', items)
    
    const itemMap = {}
    const tree = []

    // First pass: create map of items
    items.forEach(item => {
      itemMap[item.id] = { ...item, children: [] }
      console.log('Added to itemMap:', item.id, itemMap[item.id])
    })

    // Second pass: build tree structure
    items.forEach(item => {
      if (item.parent_id && itemMap[item.parent_id]) {
        itemMap[item.parent_id].children.push(itemMap[item.id])
        console.log('Added child to parent:', item.id, 'to', item.parent_id)
      } else {
        tree.push(itemMap[item.id])
        console.log('Added to root level:', item.id)
      }
    })

    // Debug output
    console.log('buildNavigationTree output:', tree)
    return tree
  }

  const handleNavClick = (item) => {
    console.log('handleNavClick called with item:', item)
    
    if (item.children?.length > 0) {
      // Only toggle expansion for parent items
      setExpandedItems(prev => ({
        ...prev,
        [item.id]: !prev[item.id]
      }))
    } else {
      // For leaf nodes (no children), handle navigation
      if (item.search_query_id) {
        navigate(`${item.url}/${item.search_query_id}`)
      } else if (item.url) {
        navigate(item.url)
      }
    }
  }

  const renderNavItems = (items) => {
    console.log('renderNavItems called with:', items)
    if (!items || items.length === 0) {
      console.log('Early return: items is null/empty')
      return null
    }
    const renderedItems = items.map(item => {
      console.log('Processing item in map:', item)
      const renderedItem = (
        <li key={item.id}>
          {item.children?.length > 0 ? (
            <>
              <button 
                className="nav-section-toggle"
                onClick={() => handleNavClick(item)}
              >
                {item.icon && <span className="nav-icon">{item.icon}</span>}
                {item.name} {expandedItems[item.id] ? '▼' : '▶'}
              </button>
              {expandedItems[item.id] && (
                <ul className="nav-section">
                  {renderNavItems(item.children)}
                </ul>
              )}
            </>
          ) : (
            <button 
              className="nav-item"
              onClick={() => handleNavClick(item)}
            >
              {item.icon && <span className="nav-icon">{item.icon}</span>}
              {item.name}
            </button>
          )}
        </li>
      )
      console.log('Rendered item result:', renderedItem)
      return renderedItem
    })
    console.log('Final rendered items:', renderedItems)
    return renderedItems
  }

  return (
    <aside className={`sidebar ${isSidebarCollapsed ? 'collapsed' : ''}`}>
      <div className="sidebar-header">
        <button 
          className="collapse-button"
          onClick={() => setIsSidebarCollapsed(!isSidebarCollapsed)}
          aria-label={isSidebarCollapsed ? 'Expand sidebar' : 'Collapse sidebar'}
        >
          {isSidebarCollapsed ? '→' : '←'}
        </button>
      </div>
      <div className="sidebar-search">
        <input type="search" placeholder="Search..." />
      </div>
      <nav className="sidebar-nav">
        <ul className="nav-list">
          {renderNavItems(navItems)}
        </ul>
      </nav>
    </aside>
  )
}